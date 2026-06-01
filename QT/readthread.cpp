#include "readthread.h"
#include <QDebug>
#include <QElapsedTimer>

#define READ_BUFFER_SIZE 3072

ReadThread::ReadThread(QObject *parent) :
    QThread(parent),
    m_deviceIndex(0),
    m_running(false),
    m_readInterval(0),
    m_writeBufferIndex(0),
    m_isWriting(false),
    m_writeCount(0),
    m_totalBytes(0),
    m_bytePosition(0),
    m_headerCount(0),
    m_footerCount(0),
    m_packetCount(0),
    m_completePacketCount(0)
{
}

ReadThread::~ReadThread()
{
    stop();
}

void ReadThread::setDeviceIndex(ULONG index)
{
    m_deviceIndex = index;
}

void ReadThread::setReadInterval(int milliseconds)
{
    QMutexLocker locker(&m_mutex);
    m_readInterval = milliseconds;
}

void ReadThread::stop()
{
    QMutexLocker locker(&m_mutex);
    m_running = false;
}

void ReadThread::getStats(quint64 &totalBytes, quint32 &headerCount, quint32 &footerCount, 
                          quint32 &packetCount, quint32 &completeCount, int &bufASize, int &bufBSize)
{
    QMutexLocker locker(&m_mutex);
    totalBytes = m_totalBytes;
    headerCount = m_headerCount;
    footerCount = m_footerCount;
    packetCount = m_packetCount;
    completeCount = m_completePacketCount;
    bufASize = m_bufferA.size();
    bufBSize = m_bufferB.size();
}

void ReadThread::run()
{
    {
        QMutexLocker locker(&m_mutex);
        m_running = true;
        m_totalBytes = 0;
        m_bytePosition = 0;
        m_headerCount = 0;
        m_footerCount = 0;
        m_packetCount = 0;
        m_completePacketCount = 0;
        m_writeBufferIndex = 0;
        m_isWriting = false;
        m_writeCount = 0;
        m_bufferA.clear();
        m_bufferB.clear();
    }
    
    BYTE *buffer = new BYTE[READ_BUFFER_SIZE];
    QElapsedTimer timer;
    QElapsedTimer statsTimer;
    timer.start();
    statsTimer.start();
    
    quint8 prevByte = 0;
    bool hasPrevByte = false;
    
    while (true) {
        {
            QMutexLocker locker(&m_mutex);
            if (!m_running) {
                break;
            }
        }
        
        int interval = 0;
        {
            QMutexLocker locker(&m_mutex);
            interval = m_readInterval;
        }
        
        if (interval > 0) {
            qint64 elapsed = timer.elapsed();
            if (elapsed < interval) {
                QThread::msleep(interval - elapsed);
            }
            timer.restart();
        }
        
        ULONG bytesRead = READ_BUFFER_SIZE;
        BOOL result = CH346ReadData(m_deviceIndex, buffer, &bytesRead);
        
        if (result && bytesRead > 0) {
            quint8 *data = reinterpret_cast<quint8*>(buffer);
            
            QMutexLocker locker(&m_mutex);
            
            for (ULONG i = 0; i < bytesRead; i++) {
                quint8 byte = data[i];
                
                if ((m_bytePosition % BLOCK_SIZE) >= 4) {
                    if (!m_isWriting) {
                        if (hasPrevByte && prevByte == HEADER_BYTE1 && byte == HEADER_BYTE2) {
                            m_headerCount++;
                            m_isWriting = true;
                            m_writeCount = 0;
                            
                            QByteArray *writeBuf = (m_writeBufferIndex == 0) ? &m_bufferA : &m_bufferB;
                            writeBuf->clear();
                            writeBuf->append(prevByte);
                            writeBuf->append(byte);
                            m_writeCount = 2;
                        }
                    } else {
                        QByteArray *currentBuf = (m_writeBufferIndex == 0) ? &m_bufferA : &m_bufferB;
                        
                        if (m_writeCount < MAX_PACKET_SIZE) {
                            currentBuf->append(byte);
                            m_writeCount++;
                            
                            if (hasPrevByte && prevByte == FOOTER_BYTE1 && byte == FOOTER_BYTE2) {
                                m_footerCount++;
                                m_packetCount++;
                                m_isWriting = false;
                                
                                if (m_writeCount == IMAGE_DATA_SIZE) {
                                    m_completePacketCount++;
                                    QByteArray imageData = *currentBuf;
                                    locker.unlock();
                                    emit imageDataReady(imageData);
                                    locker.relock();
                                }
                                
                                m_writeBufferIndex = 1 - m_writeBufferIndex;
                                m_writeCount = 0;
                            }
                        } else {
                            if (hasPrevByte && prevByte == FOOTER_BYTE1 && byte == FOOTER_BYTE2) {
                                m_footerCount++;
                                m_packetCount++;
                                m_isWriting = false;
                                m_writeBufferIndex = 1 - m_writeBufferIndex;
                                m_writeCount = 0;
                            }
                        }
                    }
                }
                
                prevByte = byte;
                hasPrevByte = true;
                m_bytePosition++;
                m_totalBytes++;
            }
            
            if (statsTimer.elapsed() >= 500) {
                emit statsUpdated(m_totalBytes, m_headerCount, m_footerCount,
                                  m_packetCount, m_completePacketCount,
                                  m_bufferA.size(), m_bufferB.size());
                statsTimer.restart();
            }
        }
    }
    
    delete[] buffer;
}
