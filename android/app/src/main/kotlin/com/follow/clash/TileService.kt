package com.follow.clash

import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.follow.clash.common.GlobalState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class TileService : TileService() {
    private var scope: CoroutineScope? = null
    private fun updateTile(runState: RunState) {
        if (qsTile != null) {
            qsTile.state = when (runState) {
                RunState.START -> Tile.STATE_ACTIVE
                RunState.PENDING -> Tile.STATE_UNAVAILABLE
                RunState.STOP -> Tile.STATE_INACTIVE
            }
            qsTile.updateTile()
        }
    }

    override fun onStartListening() {
        super.onStartListening()
        scope?.cancel()
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        scope?.launch {
            State.handleSyncState()
            State.runStateFlow.collect {
                updateTile(it)
            }
        }
    }

    override fun onClick() {
        super.onClick()
        // A tile click must stay in the background. Starting a transparent Activity here
        // can bring the Flutter task to the foreground on some Android launchers.
        GlobalState.launch {
            State.handleToggleAction()
        }
    }

    override fun onStopListening() {
        scope?.cancel()
        super.onStopListening()
    }
}
