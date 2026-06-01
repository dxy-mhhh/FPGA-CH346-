#include "widget.h"
#include "ui_widget.h"
#include <QDebug>
#include <QDateTime>

Widget::Widget(QWidget *parent) :
    QWidget(parent),
    ui(new Ui::Widget),
    m_deviceIndex(0),
    m_deviceOpened(false),
    m_readThread(nullptr),
    m_imageThread(nullptr),
    m_speedTimer(nullptr),
    m_lastTotalBytes(0),
    m_lastTime(0)
{
    ui->setupUi(this);
    
    m_imageThread = new ImageProcessThread(this);
    m_imageThread->start();
    
    m_readThread = new ReadThread(this);
    m_readThread->setDeviceIndex(m_deviceIndex);
    
    connect(m_readThread, &ReadThread::imageDataReady, m_imageThread, &ImageProcessThread::processImage);
    connect(m_imageThread, &ImageProcessThread::imageReady, this, &Widget::onImageReady, Qt::QueuedConnection);
    connect(m_readThread, &ReadThread::statsUpdated, this, &Widget::onStatsUpdated, Qt::QueuedConnection);
    
    m_speedTimer = new QTimer(this);
    m_speedTimer->setInterval(1000);
    connect(m_speedTimer, &QTimer::timeout, this, &Widget::updateSpeed);
    
    HANDLE hDevice = CH346OpenDevice(m_deviceIndex);
    if (hDevice == INVALID_HANDLE_VALUE) {
        qDebug() << "无法打开CH346设备";
        ui->textEdit->setText("状态: 设备未打开");
        ui->label_2->setText("传输速度: 0 KB/s");
        m_deviceOpened = false;
    } else {
        mDeviceInforS deviceInfo;
        BOOL infoResult = CH346GetDeviceInfor(m_deviceIndex, &deviceInfo);
        if (infoResult) {
            qDebug() << "CH346设备打开成功";
            ui->textEdit->setText("状态: 设备已连接，点击按钮开始读取");
            ui->label_2->setText("传输速度: 0 KB/s");
            m_deviceOpened = true;
        } else {
            qDebug() << "设备打开但无法获取信息，可能未连接";
            ui->textEdit->setText("状态: 设备未连接");
            ui->label_2->setText("传输速度: 0 KB/s");
            m_deviceOpened = false;
            CH346CloseDevice(m_deviceIndex);
        }
    }
    
    m_lastTime = QDateTime::currentMSecsSinceEpoch();
}

Widget::~Widget()
{
    if (m_speedTimer) {
        m_speedTimer->stop();
    }
    if (m_readThread) {
        m_readThread->stop();
        m_readThread->wait();
    }
    if (m_imageThread) {
        m_imageThread->stop();
        m_imageThread->wait();
    }
    if (m_deviceOpened) {
        CH346CloseDevice(m_deviceIndex);
    }
    delete ui;
}

void Widget::on_pushButton_clicked()
{
    if (!m_deviceOpened) {
        HANDLE hDevice = CH346OpenDevice(m_deviceIndex);
        if (hDevice == INVALID_HANDLE_VALUE) {
            ui->textEdit->setText("状态: 设备未打开");
            return;
        }
        
        mDeviceInforS deviceInfo;
        BOOL infoResult = CH346GetDeviceInfor(m_deviceIndex, &deviceInfo);
        if (!infoResult) {
            ui->textEdit->setText("状态: 设备未连接");
            CH346CloseDevice(m_deviceIndex);
            return;
        }
        
        m_deviceOpened = true;
        ui->textEdit->setText("状态: 设备已连接");
    }
    
    if (!m_readThread->isRunning()) {
        m_lastTotalBytes = 0;
        m_lastTime = QDateTime::currentMSecsSinceEpoch();
        
        int interval = ui->spinBox_interval->value();
        m_readThread->setReadInterval(interval);
        m_readThread->start();
        m_speedTimer->start();
        ui->pushButton->setText("暂停读取");
    } else {
        m_readThread->stop();
        m_readThread->wait();
        m_speedTimer->stop();
        ui->pushButton->setText("开始读取");
        
        quint64 totalBytes;
        quint32 headerCount, footerCount, packetCount, completeCount;
        int bufASize, bufBSize;
        m_readThread->getStats(totalBytes, headerCount, footerCount, packetCount, completeCount, bufASize, bufBSize);
        
        QString display = QString("状态: 已暂停读取\n");
        display += QString("总字节数: %1\n").arg(totalBytes);
        display += QString("缓冲区A: %1 字节\n").arg(bufASize);
        display += QString("缓冲区B: %1 字节\n\n").arg(bufBSize);
        display += QString("包头(0xCDAB): %1 个\n").arg(headerCount);
        display += QString("包尾(0xBADC): %1 个\n").arg(footerCount);
        display += QString("协议数据包: %1 个\n").arg(packetCount);
        display += QString("完整图片包: %1 个\n").arg(completeCount);
        ui->textEdit->setText(display);
    }
}

void Widget::onImageReady(const QImage &image)
{
    ui->label_image->setPixmap(QPixmap::fromImage(image.scaled(400, 240, Qt::KeepAspectRatio)));
}

void Widget::onStatsUpdated(quint64 totalBytes, quint32 headerCount, quint32 footerCount,
                             quint32 packetCount, quint32 completeCount, int bufASize, int bufBSize)
{
    QString display = QString("状态: 正在读取数据...\n");
    display += QString("总字节数: %1\n").arg(totalBytes);
    display += QString("缓冲区A: %1 字节\n").arg(bufASize);
    display += QString("缓冲区B: %1 字节\n\n").arg(bufBSize);
    display += QString("包头(0xCDAB): %1 个\n").arg(headerCount);
    display += QString("包尾(0xBADC): %1 个\n").arg(footerCount);
    display += QString("协议数据包: %1 个\n").arg(packetCount);
    display += QString("完整图片包: %1 个\n").arg(completeCount);
    ui->textEdit->setText(display);
}

void Widget::updateSpeed()
{
    quint64 totalBytes;
    quint32 headerCount, footerCount, packetCount, completeCount;
    int bufASize, bufBSize;
    m_readThread->getStats(totalBytes, headerCount, footerCount, packetCount, completeCount, bufASize, bufBSize);
    
    qint64 currentTime = QDateTime::currentMSecsSinceEpoch();
    qint64 elapsed = currentTime - m_lastTime;
    
    if (elapsed > 0 && m_lastTime > 0) {
        quint64 bytesDiff = totalBytes - m_lastTotalBytes;
        double speedKB = (bytesDiff / 1024.0) / (elapsed / 1000.0);
        ui->label_2->setText(QString("传输速度: %1 KB/s").arg(speedKB, 0, 'f', 2));
    }
    
    m_lastTotalBytes = totalBytes;
    m_lastTime = currentTime;
}
