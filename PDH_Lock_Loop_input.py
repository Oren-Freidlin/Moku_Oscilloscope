import numpy as np
import matplotlib.pyplot as plt
import scipy.signal as sci
import time

# ======================
# PID controller
# ======================
class PID:
    def __init__(self, p_coef, i_coef, d_coef):
        self.p_coef = p_coef
        self.i_coef = i_coef
        self.d_coef = d_coef
        self.last_error = 0.0
        self.integral = 0.0

    def PID_response(self, error, dt):
        P = self.p_coef * error
        self.integral += error * dt
        I = self.i_coef * self.integral
        derivative = (error - self.last_error) / dt
        D = self.d_coef * derivative
        self.last_error = error
        return P + I + D


# ======================
# Fake oscilloscope setup
# ======================
fs = 39.063e6
N = 1024
t = np.arange(N) / fs

def fake_oscilloscope():
    """Simulate one oscilloscope acquisition"""
    return (
        0.2 * np.sin(2 * np.pi * 10e3 * t) +
        0.02 * np.random.randn(len(t))
    )


# ======================
# Controller parameters
# ======================
p_coef = -60
i_coef = 120
d_coef = 1
target = 0.0

pid = PID(p_coef, i_coef, d_coef)

# Low-pass filter (create once)
sos = sci.butter(
    12, 150e3,
    btype='lowpass',
    output='sos',
    fs=fs
)

# ======================
# Real-time plot setup
# ======================
plt.ion()
fig, ax = plt.subplots()

line_error, = ax.plot(t, np.zeros_like(t), label="Error")
line_pid,   = ax.plot(t, np.zeros_like(t), label="PID Output")

ax.set_xlabel("Time (s)")
ax.set_ylabel("Amplitude")
ax.legend()
ax.set_ylim(-5, 5)

plt.show()


# ======================
# Main real-time loop
# ======================
sim_time = 10.0
dt = t[1] - t[0]

while sim_time > 0:

    # --- Fake oscilloscope acquisition ---
    osc_volt = fake_oscilloscope()

    # --- Signal processing ---
    osc_singlederiv = np.gradient(osc_volt, t)
    osc_doublederiv = np.gradient(osc_singlederiv, t)

    filtered_osc = sci.sosfilt(sos, osc_volt)
    filtered_deriv = sci.sosfilt(sos, osc_singlederiv)
    filtered_double_deriv = sci.sosfilt(sos, osc_doublederiv)

    feedback = (
        filtered_osc +
        filtered_deriv +
        filtered_double_deriv
    )

    error = target - feedback

    # --- PID evaluation (sample-by-sample) ---
    pid_output = np.zeros_like(error)
    for i, e in enumerate(error):
        pid_output[i] = pid.PID_response(e, dt)

    # --- Update plot ---
    line_error.set_ydata(error)
    line_pid.set_ydata(pid_output)

    ax.relim()
    ax.autoscale_view(scalex=False)

    plt.pause(0.01)   # GUI refresh + timing
    time.sleep(0.05)  # simulate acquisition latency

    sim_time -= 0.05


plt.ioff()
plt.show()