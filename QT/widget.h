#ifndef WIDGET_H
#define WIDGET_H

#include <QWidget>
#include <QTextEdit>
#include <QTimer>
#include <windows.h>
#include "CH346DLL.H"
#include "readthread.h"
#include "imageprocessthread.h"

namespace Ui {
class Widget;
}

class Widget : public QWidget
{
    Q_OBJECT

public:
    explicit Widget(QWidget *parent = 0);
    ~Widget();

private slots:
    void on_pushButton_clicked();
    void onImageReady(const QImage &image);
    void onStatsUpdated(quint64 totalBytes, quint32 headerCount, quint32 footerCount,
                         quint32 packetCount, quint32 completeCount, int bufASize, int bufBSize);
    void updateSpeed();

private:
    Ui::Widget *ui;
    ULONG m_deviceIndex;
    bool m_deviceOpened;
    ReadThread *m_readThread;
    ImageProcessThread *m_imageThread;
    QTimer *m_speedTimer;
    quint64 m_lastTotalBytes;
    qint64 m_lastTime;
};

#endif // WIDGET_H
