#ifndef IMAGEPROCESSTHREAD_H
#define IMAGEPROCESSTHREAD_H

#include <QThread>
#include <QMutex>
#include <QWaitCondition>
#include <QImage>
#include <QByteArray>

#define IMAGE_DATA_SIZE 768000
#define IMAGE_WIDTH 800
#define IMAGE_HEIGHT 480

class ImageProcessThread : public QThread
{
    Q_OBJECT

public:
    explicit ImageProcessThread(QObject *parent = nullptr);
    ~ImageProcessThread();
    
    void processImage(const QByteArray &data);
    void stop();

signals:
    void imageReady(const QImage &image);

protected:
    void run() override;

private:
    QByteArray m_imageData;
    QMutex m_mutex;
    QWaitCondition m_condition;
    bool m_running;
    bool m_hasData;
};

#endif // IMAGEPROCESSTHREAD_H
