package main

import (
	"errors"
	"sync/atomic"
	"testing"
	"time"
)

func TestGeoUpdateSchedulerDefersInitialUpdateAndRetriesAfterFailure(t *testing.T) {
	var calls atomic.Int32
	firstCall := make(chan struct{})
	secondCall := make(chan struct{})
	scheduler := geoUpdateScheduler{}
	t.Cleanup(scheduler.stop)

	scheduler.configure(
		true,
		10*time.Millisecond,
		40*time.Millisecond,
		func() error {
			switch calls.Add(1) {
			case 1:
				close(firstCall)
				return errors.New("network unavailable")
			case 2:
				close(secondCall)
			}
			return nil
		},
		nil,
	)

	select {
	case <-firstCall:
		t.Fatal("Geo update started before the startup delay")
	case <-time.After(10 * time.Millisecond):
	}

	select {
	case <-firstCall:
	case <-time.After(300 * time.Millisecond):
		t.Fatal("Geo update did not start after the startup delay")
	}

	select {
	case <-secondCall:
	case <-time.After(300 * time.Millisecond):
		t.Fatal("Geo updater stopped after the first failed attempt")
	}
}

func TestGeoUpdateSchedulerStopsWhenDisabled(t *testing.T) {
	var calls atomic.Int32
	firstCall := make(chan struct{})
	scheduler := geoUpdateScheduler{}
	t.Cleanup(scheduler.stop)

	scheduler.configure(
		true,
		10*time.Millisecond,
		0,
		func() error {
			if calls.Add(1) == 1 {
				close(firstCall)
			}
			return nil
		},
		nil,
	)

	select {
	case <-firstCall:
	case <-time.After(300 * time.Millisecond):
		t.Fatal("Geo updater did not start")
	}

	scheduler.configure(false, 10*time.Millisecond, 0, func() error {
		calls.Add(1)
		return nil
	}, nil)
	callsAfterStop := calls.Load()
	time.Sleep(50 * time.Millisecond)
	if got := calls.Load(); got != callsAfterStop {
		t.Fatalf("Geo updater continued after being disabled: calls before=%d after=%d", callsAfterStop, got)
	}
}

func TestGeoUpdateSchedulerDoesNotStartWhenDisabled(t *testing.T) {
	var calls atomic.Int32
	scheduler := geoUpdateScheduler{}
	t.Cleanup(scheduler.stop)

	scheduler.configure(false, time.Millisecond, 0, func() error {
		calls.Add(1)
		return nil
	}, nil)
	time.Sleep(20 * time.Millisecond)
	if got := calls.Load(); got != 0 {
		t.Fatalf("disabled Geo updater ran %d times", got)
	}
}
