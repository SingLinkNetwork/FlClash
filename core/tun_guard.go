package main

import "unsafe"

func tunCallbackAvailable(listenerPresent bool, callback unsafe.Pointer) bool {
	return listenerPresent && callback != nil
}
