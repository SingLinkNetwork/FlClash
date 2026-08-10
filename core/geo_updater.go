package main

import (
	"context"
	"sync"
	"time"

	"github.com/metacubex/mihomo/component/updater"
	"github.com/metacubex/mihomo/log"
)

const geoUpdaterStartupDelay = 30 * time.Second

// geoUpdateScheduler owns the lifecycle of the automatic Geo updater.
// Keeping the context here lets the Flutter bridge stop an old schedule when
// a profile is replaced or the user turns automatic updates off.
type geoUpdateScheduler struct {
	mu     sync.Mutex
	cancel context.CancelFunc
}

func (s *geoUpdateScheduler) configure(
	enabled bool,
	interval time.Duration,
	startupDelay time.Duration,
	update func() error,
	onError func(error),
) {
	s.stop()
	if !enabled || interval <= 0 || update == nil {
		return
	}

	ctx, cancel := context.WithCancel(context.Background())
	s.mu.Lock()
	s.cancel = cancel
	s.mu.Unlock()

	go func() {
		startupTimer := time.NewTimer(startupDelay)
		defer startupTimer.Stop()
		select {
		case <-ctx.Done():
			return
		case <-startupTimer.C:
		}

		run := func() {
			if err := update(); err != nil && onError != nil {
				onError(err)
			}
		}
		run()

		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				run()
			}
		}
	}()
}

func (s *geoUpdateScheduler) stop() {
	s.mu.Lock()
	cancel := s.cancel
	s.cancel = nil
	s.mu.Unlock()
	if cancel != nil {
		cancel()
	}
}

var geoUpdater geoUpdateScheduler

func configureGeoUpdater() {
	geoUpdater.configure(
		isRunning && updater.GeoAutoUpdate(),
		time.Duration(updater.GeoUpdateInterval())*time.Hour,
		geoUpdaterStartupDelay,
		updater.UpdateGeoDatabases,
		func(err error) {
			log.Errorln("[GEO] Automatic update failed; will retry: %s", err.Error())
		},
	)
}
