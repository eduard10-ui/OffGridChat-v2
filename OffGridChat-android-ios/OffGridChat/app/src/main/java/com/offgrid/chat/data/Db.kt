package com.offgrid.chat.data

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Entity(tableName = "peers")
data class PeerEntity(
    @PrimaryKey val id: String,
    val nick: String,
    val signPub: String,
    val agreePub: String,
    val verified: Boolean = false,
    val lastSeen: Long = 0
)

@Entity(tableName = "messages")
data class MessageEntity(
    @PrimaryKey val id: String,
    val convId: String,
    val senderId: String,
    val receiverId: String,
    val text: String,
    val ts: Long,
    val status: String,     // QUEUED, SENT, DELIVERED, FAILED, RECEIVED
    val outgoing: Boolean,
    val type: String,
    val attempts: Int = 0
)

@Dao
interface ChatDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun upsertPeer(p: PeerEntity)
    @Query("SELECT * FROM peers") fun peers(): Flow<List<PeerEntity>>
    @Query("SELECT * FROM peers WHERE id = :id") suspend fun peer(id: String): PeerEntity?
    @Query("UPDATE peers SET verified = 1 WHERE id = :id") suspend fun setVerified(id: String)

    @Insert(onConflict = OnConflictStrategy.IGNORE) suspend fun insertMsg(m: MessageEntity): Long
    @Query("SELECT * FROM messages WHERE convId = :c ORDER BY ts") fun conv(c: String): Flow<List<MessageEntity>>
    @Query("UPDATE messages SET status = :s WHERE id = :id AND status != 'DELIVERED'")
    suspend fun updateStatus(id: String, s: String)
    @Query("SELECT * FROM messages WHERE outgoing = 1 AND type = 'CHAT' AND receiverId = :p AND status IN ('QUEUED','SENT')")
    suspend fun pendingFor(p: String): List<MessageEntity>
    @Query("SELECT * FROM messages WHERE outgoing = 1 AND type = 'CHAT' AND status IN ('QUEUED','SENT')")
    suspend fun allPending(): List<MessageEntity>
    @Query("UPDATE messages SET attempts = attempts + 1 WHERE id = :id") suspend fun bump(id: String)
    @Query("UPDATE messages SET status = 'QUEUED', attempts = 0 WHERE id = :id AND status = 'FAILED'")
    suspend fun resetFailed(id: String)
    @Query("SELECT * FROM messages WHERE id = :id") suspend fun msg(id: String): MessageEntity?
}

@Database(entities = [PeerEntity::class, MessageEntity::class], version = 1, exportSchema = false)
abstract class AppDb : RoomDatabase() {
    abstract fun dao(): ChatDao
}
