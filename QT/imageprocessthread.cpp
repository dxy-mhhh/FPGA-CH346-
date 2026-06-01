#include "imageprocessthread.h"

ImageProcessThread::ImageProcessThread(QObject *parent) :
    QThread(parent),
    m_running(false),
    m_hasData(false)
{
}

ImageProcessThread::~ImageProcessThread()
{
    stop();
}

void ImageProcessThread::processImage(const QByteArray &data)
{
    QMutexLocker locker(&m_mutex);
    m_imageData = data;
    m_hasData = true;
    m_condition.wakeOne();
}

void ImageProcessThread::stop()
{
    QMutexLocker locker(&m_mutex);
    m_running = false;
    m_hasData = true;
    m_condition.wakeOne();
}

void ImageProcessThread::run()
{
    m_running = true;
    
    while (true) {
        QByteArray data;
        
        {
            QMutexLocker locker(&m_mutex);
            while (!m_hasData && m_running) {
                m_condition.wait(&m_mutex);
            }
            
            if (!m_running) {
                break;
            }
            
            data = m_imageData;
            m_imageData.clear();
            m_hasData = false;
        }
        
        if (data.size() >= IMAGE_DATA_SIZE) {
            QImage image(IMAGE_WIDTH, IMAGE_HEIGHT, QImage::Format_RGB32);
            
            const quint8 *src = reinterpret_cast<const quint8*>(data.constData());
            QRgb *dst = reinterpret_cast<QRgb*>(image.bits());
            
            for (int i = 0; i < IMAGE_WIDTH * IMAGE_HEIGHT; i++) {
                quint16 pixel = src[i * 2] | (src[i * 2 + 1] << 8);
                
                quint8 r = (pixel >> 11) & 0x1F;
                quint8 g = (pixel >> 5) & 0x3F;
                quint8 b = pixel & 0x1F;
                
                r = (r * 255) / 31;
                g = (g * 255) / 63;
                b = (b * 255) / 31;
                
                dst[i] = qRgb(r, g, b);
            }
            
            emit imageReady(image);
        }
    }
}
