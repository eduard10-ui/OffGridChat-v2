package com.offgrid.chat.crypto

import android.util.Base64
import com.google.crypto.tink.subtle.Ed25519Sign
import com.google.crypto.tink.subtle.Ed25519Verify
import com.google.crypto.tink.subtle.Hkdf
import com.google.crypto.tink.subtle.X25519
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

fun ByteArray.b64(): String = Base64.encodeToString(this, Base64.NO_WRAP)
fun String.unb64(): ByteArray = Base64.decode(this, Base64.NO_WRAP)
fun ByteArray.hex(): String = joinToString("") { "%02x".format(it) }

class Identity(
    val signSeed: ByteArray, val signPub: ByteArray,
    val agreePriv: ByteArray, val agreePub: ByteArray
) {
    /** Self-certifying ID: first 128 bits of SHA-256(signPub || agreePub). */
    val userId: String = Crypto.userId(signPub, agreePub)
}

object Crypto {
    private val rng = SecureRandom()

    fun userId(signPub: ByteArray, agreePub: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(signPub + agreePub).hex().take(32)

    fun fingerprint(userId: String): String = userId.uppercase().chunked(4).joinToString(" ")

    fun newIdentity(): Identity {
        val kp = Ed25519Sign.KeyPair.newKeyPair()
        val priv = X25519.generatePrivateKey()
        return Identity(kp.privateKey, kp.publicKey, priv, X25519.publicFromPrivate(priv))
    }

    fun sign(id: Identity, data: ByteArray): String = Ed25519Sign(id.signSeed).sign(data).b64()

    fun verify(pub: ByteArray, data: ByteArray, sigB64: String): Boolean = try {
        Ed25519Verify(pub).verify(sigB64.unb64(), data); true
    } catch (e: Exception) { false }

    /** X25519 -> HKDF-SHA256 -> 32-byte AES-256 key (same on both sides). */
    fun sharedKey(me: Identity, theirAgreePub: ByteArray): ByteArray {
        val secret = X25519.computeSharedSecret(me.agreePriv, theirAgreePub)
        val sorted = listOf(me.agreePub, theirAgreePub).sortedBy { it.hex() }
        return Hkdf.computeHkdf("HmacSha256", secret, sorted[0] + sorted[1], "offgrid-e2e-v1".toByteArray(), 32)
    }

    fun encrypt(key: ByteArray, aad: ByteArray, plain: ByteArray): String {
        val iv = ByteArray(12).also { rng.nextBytes(it) }
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, iv))
        c.updateAAD(aad)
        return (iv + c.doFinal(plain)).b64()
    }

    fun decrypt(key: ByteArray, aad: ByteArray, b64: String): ByteArray? = try {
        val all = b64.unb64()
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, all.copyOfRange(0, 12)))
        c.updateAAD(aad)
        c.doFinal(all, 12, all.size - 12)
    } catch (e: Exception) { null }
}
