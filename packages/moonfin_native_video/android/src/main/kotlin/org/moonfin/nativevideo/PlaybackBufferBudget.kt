package org.moonfin.nativevideo

internal object PlaybackBufferBudget {
    fun constrained(lowRam: Boolean, is64Bit: Boolean, totalMemory: Long): Boolean =
        lowRam || !is64Bit || (totalMemory > 0 && totalMemory <= 2L * 1024 * 1024 * 1024)

    fun bytes(maxHeap: Long, constrained: Boolean, minimum: Long): Int =
        (maxHeap / if (constrained) 8 else 3)
            .coerceAtMost(if (constrained) 24L * 1024 * 1024 else 384L * 1024 * 1024)
            .coerceAtLeast(minimum)
            .toInt()
}
