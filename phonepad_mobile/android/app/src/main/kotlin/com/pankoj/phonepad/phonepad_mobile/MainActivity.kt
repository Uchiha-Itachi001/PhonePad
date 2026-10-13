package com.pankoj.phonepad.phonepad_mobile

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.OutputStream
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.pankoj.phonepad/bluetooth"
    private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    private var bluetoothSocket: BluetoothSocket? = null
    private var outputStream: OutputStream? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var methodChannel: MethodChannel? = null

    @SuppressLint("MissingPermission")
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            val adapter = BluetoothAdapter.getDefaultAdapter()

            when (call.method) {
                "requestPermissions" -> {
                    checkAndRequestPermissions()
                    result.success(true)
                }
                "isBluetoothSupported" -> {
                    result.success(adapter != null)
                }
                "isBluetoothEnabled" -> {
                    result.success(adapter?.isEnabled == true)
                }
                "getPairedDevices" -> {
                    if (adapter == null) {
                        result.success(emptyList<Map<String, String>>())
                        return@setMethodCallHandler
                    }

                    // Auto-request permissions on Android 12+ if not yet granted
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        if (checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                            checkAndRequestPermissions()
                            result.success(emptyList<Map<String, String>>())
                            return@setMethodCallHandler
                        }
                    }

                    try {
                        val devices = adapter.bondedDevices.map { device ->
                            mapOf(
                                "name" to (device.name ?: "Unknown Device"),
                                "address" to device.address
                            )
                        }
                        result.success(devices)
                    } catch (e: Exception) {
                        result.error("PERMISSION_ERROR", e.message, null)
                    }
                }
                "connect" -> {
                    val address = call.argument<String>("address")
                    if (address == null || adapter == null) {
                        result.error("INVALID_ARGS", "Device address or adapter null", null)
                        return@setMethodCallHandler
                    }

                    notifyStatus("connecting")
                    executor.execute {
                        try {
                            adapter.cancelDiscovery()
                            val device = adapter.getRemoteDevice(address)

                            var socket: BluetoothSocket? = null
                            var connectException: Exception? = null

                            // 1. Strategy 1: Standard Secure SPP via Service Record UUID
                            try {
                                val s = device.createRfcommSocketToServiceRecord(SPP_UUID)
                                s.connect()
                                socket = s
                            } catch (e: Exception) {
                                connectException = e
                            }

                            // 2. Strategy 2: Insecure SPP via Service Record UUID (bypasses Windows auth hitch)
                            if (socket == null || !socket.isConnected) {
                                try {
                                    val s = device.createInsecureRfcommSocketToServiceRecord(SPP_UUID)
                                    s.connect()
                                    socket = s
                                } catch (e: Exception) {
                                    connectException = e
                                }
                            }

                            // 3. Strategy 3: Dynamic RFCOMM reflection channel scan (channels 1 through 6)
                            if (socket == null || !socket.isConnected) {
                                for (ch in 1..6) {
                                    try {
                                        val m = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
                                        val s = m.invoke(device, ch) as BluetoothSocket
                                        s.connect()
                                        socket = s
                                        break
                                    } catch (_: Exception) {}
                                }
                            }

                            if (socket == null || !socket.isConnected) {
                                throw connectException ?: IOException("Unable to connect via Bluetooth RFCOMM")
                            }

                            synchronized(this) {
                                bluetoothSocket = socket
                                outputStream = socket.outputStream
                            }

                            notifyStatus("connected")
                            mainHandler.post { result.success(true) }

                            // Keepalive and disconnect detector loop
                            val inputStream = socket.inputStream
                            val dummyBuffer = ByteArray(64)
                            try {
                                while (socket.isConnected) {
                                    val bytesRead = inputStream.read(dummyBuffer)
                                    if (bytesRead == -1) break
                                }
                            } catch (_: IOException) {
                            } finally {
                                disconnectInternal()
                            }
                        } catch (e: Exception) {
                            disconnectInternal()
                            mainHandler.post {
                                result.error("CONNECTION_FAILED", e.message, null)
                            }
                        }
                    }
                }
                "sendBytes" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null) {
                        result.error("INVALID_ARGS", "Bytes argument null", null)
                        return@setMethodCallHandler
                    }
                    result.success(true)

                    executor.execute {
                        try {
                            synchronized(this) {
                                outputStream?.write(bytes)
                                outputStream?.flush()
                            }
                        } catch (e: Exception) {
                            disconnectInternal()
                        }
                    }
                }
                "disconnect" -> {
                    executor.execute {
                        disconnectInternal()
                        mainHandler.post { result.success(true) }
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun checkAndRequestPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val permissions = mutableListOf<String>()
            if (checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
            }
            if (checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) {
                permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            }
            if (permissions.isNotEmpty()) {
                requestPermissions(permissions.toTypedArray(), 1001)
            }
        }
    }

    private fun disconnectInternal() {
        synchronized(this) {
            try {
                outputStream?.close()
                bluetoothSocket?.close()
            } catch (_: Exception) {}
            outputStream = null
            bluetoothSocket = null
        }
        notifyStatus("disconnected")
    }

    private fun notifyStatus(status: String) {
        mainHandler.post {
            methodChannel?.invokeMethod("onStatusChanged", status)
        }
    }

    override fun onDestroy() {
        disconnectInternal()
        executor.shutdown()
        super.onDestroy()
    }
}
