#ifndef READTHREAD_H
#define READTHREAD_H

#include <QThread>
#include <QMutex>
#include <QByteArray>
#include <windows.h>
#include "CH346DLL.H"

#define HEADER_BYTE1 0xCD
#define HEADER_BYTE2 0xAB
#define FOOTER_BYTE1 0xBA
#define FOOTER_BYTE2 0xDC
#define BLOCK_SIZE 512
#define MAX_PACKET_SIZE 770000
#define IMAGE_DATA_SIZE 768000

class ReadThread : public QThread
{
    Q_OBJECT

public:
    explicit ReadThread(QObject *parent = nullptr);
    ~ReadThread();
    
    void setDeviceIndex(ULONG index);
    void setReadInterval(int milliseconds);
    void stop();
    void getStats(quint64 &totalBytes, quint32 &headerCount, quint32 &footerCount, 
                  quint32 &packetCount, quint32 &completeCount, int &bufASize, int &bufBSize);

signals:
    void imageDataReady(const QByteArray &data);
    void statsUpdated(quint64 totalBytes, quint32 headerCount, quint32 footerCount,
                      quint32 packetCount, quint32 completeCount, int bufASize, int bufBSize);

protected:
    void run() override;

private:
    ULONG m_deviceIndex;
    bool m_running;
    int m_readInterval;
    QMutex m_mutex;
    
    QByteArray m_bufferA;
    QByteArray m_bufferB;
    int m_writeBufferIndex;
    bool m_isWriting;
    int m_writeCount;
    
    quint64 m_totalBytes;
    quint64 m_bytePosition;
    quint32 m_headerCount;
    quint32 m_footerCount;
    quint32 m_packetCount;
    quint32 m_completePacketCount;
};

#endif // READTHREAD_H
