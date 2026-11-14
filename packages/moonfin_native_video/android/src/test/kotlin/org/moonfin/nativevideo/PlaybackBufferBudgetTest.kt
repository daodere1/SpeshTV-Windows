package org.moonfin.nativevideo

import org.junit.Assert.*
import org.junit.Test

class PlaybackBufferBudgetTest {
    @Test fun shield32BitGetsConstrainedBudget() {
        assertTrue(PlaybackBufferBudget.constrained(false, false, 2L shl 30))
        assertEquals(24 shl 20, PlaybackBufferBudget.bytes(512L shl 20, true, 12L shl 20))
    }
    @Test fun smallHeapRetainsAllocatorMinimum() {
        assertEquals(12 shl 20, PlaybackBufferBudget.bytes(64L shl 20, true, 12L shl 20))
    }
    @Test fun healthy64BitDeviceRetainsRunway() {
        assertFalse(PlaybackBufferBudget.constrained(false, true, 4L shl 30))
        assertEquals(128 shl 20, PlaybackBufferBudget.bytes(384L shl 20, false, 12L shl 20))
    }
    @Test fun lowRamAndTwoGigabyteDevicesAreConstrained() {
        assertTrue(PlaybackBufferBudget.constrained(true, true, 4L shl 30))
        assertTrue(PlaybackBufferBudget.constrained(false, true, 2L shl 30))
        assertFalse(PlaybackBufferBudget.constrained(false, true, 0))
    }
}
