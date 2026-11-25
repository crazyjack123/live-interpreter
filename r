<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport"
        content="width=device-width, initial-scale=1">

  <title>Live Polish Interpreter</title>

  <style>
    * {
      box-sizing: border-box;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont,
                   Arial, sans-serif;
      background: #f1f5f9;
      color: #1e293b;
      margin: 0;
      padding: 24px 16px;
      text-align: center;
    }

    .container {
      max-width: 500px;
      margin: auto;
    }

    .card {
      background: white;
      padding: 24px;
      border-radius: 20px;
      margin-bottom: 16px;
      box-shadow: 0 4px 15px rgba(0,0,0,0.06);
    }

    h1 {
      font-size: 26px;
      margin-bottom: 8px;
    }

    h2 {
      font-size: 30px;
      margin: 15px 0;
    }

    .subtitle {
      color: #64748b;
      font-size: 14px;
    }

    button {
      display: block;
      width: 100%;
      border: none;
      border-radius: 12px;
      padding: 16px;
      margin-top: 12px;
      font-size: 16px;
      font-weight: 600;
      color: white;
      cursor: pointer;
    }

    button:disabled {
      opacity: 0.5;
      cursor: default;
    }

    .start {
      background: #15803d;
    }

    .stop {
      background: #dc2626;
    }

    .diagnose {
      background: #2563eb;
    }

    .refresh {
      background: #475569;
    }

    select {
      width: 100%;
      padding: 12px;
      margin-top: 10px;
      background: white;
      border: 1px solid #cbd5e1;
      border-radius: 10px;
      font-size: 16px;
    }

    #status {
      background: #f1f5f9;
      padding: 15px;
      margin-top: 20px;
      border-radius: 10px;
      overflow-wrap: anywhere;
      font-size: 14px;
    }

    .meter-background {
      height: 18px;
      background: #e2e8f0;
      border-radius: 20px;
      overflow: hidden;
      margin-top: 15px;
    }

    #audioLevel {
      height: 100%;
      width: 0%;
      background: #22c55e;
      transition: width 0.1s;
    }

    #diagnostics {
      text-align: left;
      white-space: pre-wrap;
      overflow-wrap: anywhere;
      background: #0f172a;
      color: #e2e8f0;
      border-radius: 12px;
      padding: 16px;
      font-size: 12px;
      line-height: 1.7;
      min-height: 70px;
    }

    #micName {
      color: #475569;
      font-size: 13px;
      overflow-wrap: anywhere;
    }

    .notice {
      color: #64748b;
      font-size: 12px;
      line-height: 1.6;
    }
  </style>
</head>

<body>

<div class="container">

  <div class="card">
    <h1>Live Interpreter</h1>
    <h2>🇵🇱 → 🇬🇧</h2>

    <p class="subtitle">
      Shokz OpenRun · Polish to English
    </p>

    <p>Microphone connection test</p>

    <select id="microphone">
      <option value="">
        System default microphone
      </option>
    </select>

    <button class="refresh"
            onclick="detectMicrophones()">
      Detect microphones
    </button>

    <button id="startButton"
            class="start"
            onclick="startMicrophone()">
      Start microphone
    </button>

    <button id="stopButton"
            class="stop"
            onclick="stopMicrophone()"
            disabled>
      Stop microphone
    </button>

    <div id="status">Ready to listen</div>

    <p id="micName">No microphone connected</p>

    <div class="meter-background">
      <div id="audioLevel"></div>
    </div>

    <p class="subtitle">
      Audio level: <span id="levelNumber">0</span>%
    </p>
  </div>

  <div class="card">
    <h3>System diagnostics</h3>

    <button class="diagnose"
            onclick="diagnoseMicrophone()">
      Run full diagnostics
    </button>

    <pre id="diagnostics">Press Run full diagnostics.</pre>
  </div>

  <p class="notice">
    Microphone testing only.<br>
    No audio is recorded or sent to OpenAI.<br>
    No API charges apply.
  </p>

</div>

<script>

  let stream = null;
  let audioContext = null;
  let analyser = null;
  let levelTimer = null;

  function setStatus(message, type = "normal") {
    const status = document.getElementById("status");

    status.textContent = message;

    if (type === "error") {
      status.style.background = "#fee2e2";
      status.style.color = "#991b1b";
    } else if (type === "success") {
      status.style.background = "#dcfce7";
      status.style.color = "#166534";
    } else {
      status.style.background = "#f1f5f9";
      status.style.color = "#334155";
    }
  }

  async function detectMicrophones() {

    const select =
      document.getElementById("microphone");

    const previousSelection = select.value;

    if (!navigator.mediaDevices ||
        !navigator.mediaDevices.enumerateDevices) {

      setStatus(
        "Microphone detection API unavailable.",
        "error"
      );

      return;
    }

    try {
      const devices =
        await navigator.mediaDevices.enumerateDevices();

      const microphones = devices.filter(
        device => device.kind === "audioinput"
      );

      select.innerHTML = "";

      const defaultOption =
        document.createElement("option");

      defaultOption.value = "";
      defaultOption.textContent =
        "System default microphone";

      select.appendChild(defaultOption);

      microphones.forEach((device, index) => {

        const option =
          document.createElement("option");

        option.value = device.deviceId;

        option.textContent =
          device.label || "Microphone " + (index + 1);

        select.appendChild(option);

      });

      if (
        Array.from(select.options).some(
          option => option.value === previousSelection
        )
      ) {
        select.value = previousSelection;
      }

      return microphones.length;

    } catch (error) {

      setStatus(
        "Detection error: " + error.message,
        "error"
      );

      return null;
    }
  }

  async function startMicrophone() {

    stopMicrophone();

    const startButton =
      document.getElementById("startButton");

    const stopButton =
      document.getElementById("stopButton");

    startButton.disabled = true;
    stopButton.disabled = true;

    setStatus("Requesting microphone permission...");

    try {

      if (!window.isSecureContext) {
        throw new Error(
          "Microphone requires a secure HTTPS connection."
        );
      }

      if (!navigator.mediaDevices ||
          !navigator.mediaDevices.getUserMedia) {
        throw new Error(
          "Microphone API unavailable in this browser."
        );
      }

      const AudioContextClass =
        window.AudioContext || window.webkitAudioContext;

      if (!AudioContextClass) {
        throw new Error(
          "Web Audio API is unavailable."
        );
      }

      audioContext = new AudioContextClass();
      await audioContext.resume();

      const selectedDevice =
        document.getElementById("microphone").value;

      const audioSettings = {
        echoCancellation: true,
        noiseSuppression: false,
        autoGainControl: true
      };

      if (selectedDevice) {
        audioSettings.deviceId = {
          exact: selectedDevice
        };
      }

      stream =
        await navigator.mediaDevices.getUserMedia({
          audio: audioSettings,
          video: false
        });

      analyser = audioContext.createAnalyser();

      analyser.fftSize = 1024;

      const source =
        audioContext.createMediaStreamSource(stream);

      source.connect(analyser);

      const track = stream.getAudioTracks()[0];

      document.getElementById("micName").textContent =
        "Active microphone: " +
        (track.label || "System default");

      const data =
        new Uint8Array(analyser.fftSize);

      levelTimer = setInterval(() => {

        analyser.getByteTimeDomainData(data);

        let sum = 0;

        for (let i = 0; i < data.length; i++) {
          const sample = (data[i] - 128) / 128;
          sum += sample * sample;
        }

        const rms = Math.sqrt(sum / data.length);

        const level =
          Math.min(100, Math.round(rms * 400));

        document.getElementById("audioLevel")
          .style.width = level + "%";

        document.getElementById("levelNumber")
          .textContent = level;

      }, 100);

      await detectMicrophones();

      stopButton.disabled = false;

      setStatus(
        "Microphone connected successfully",
        "success"
      );

    } catch (error) {

      stopMicrophone();

      setStatus(
        error.name + ": " + error.message,
        "error"
      );

      await diagnoseMicrophone();

    }
  }

  function stopMicrophone() {

    clearInterval(levelTimer);
    levelTimer = null;

    if (stream) {
      stream.getTracks().forEach(
        track => track.stop()
      );
      stream = null;
    }

    if (audioContext) {
      audioContext.close().catch(() => {});
      audioContext = null;
    }

    analyser = null;

    document.getElementById("audioLevel")
      .style.width = "0%";

    document.getElementById("levelNumber")
      .textContent = "0";

    document.getElementById("micName")
      .textContent = "No microphone connected";

    document.getElementById("startButton")
      .disabled = false;

    document.getElementById("stopButton")
      .disabled = true;

    setStatus("Microphone stopped");
  }

  async function diagnoseMicrophone() {

    const output =
      document.getElementById("diagnostics");

    const results = [];

    output.textContent = "Running diagnostics...";

    function report(message) {
      results.push(message);
      output.textContent = results.join("\n");
    }

    report("LIVE INTERPRETER DIAGNOSTICS");
    report("----------------------------");

    report(
      "Date: " + new Date().toLocaleString()
    );

    report(
      "HTTPS / secure context: " +
      window.isSecureContext
    );

    report(
      "Running inside iframe: " +
      (window.self !== window.top)
    );

    report(
      "MediaDevices available: " +
      !!navigator.mediaDevices
    );

    report(
      "getUserMedia available: " +
      !!navigator.mediaDevices?.getUserMedia
    );

    report(
      "AudioContext available: " +
      !!(window.AudioContext ||
         window.webkitAudioContext)
    );

    report("");
    report("PERMISSIONS POLICY");
    report("----------------------------");

    const policy =
      document.permissionsPolicy ||
      document.featurePolicy;

    let policyAllowsMic = null;

    try {

      if (policy &&
          typeof policy.allowsFeature === "function") {

        policyAllowsMic =
          policy.allowsFeature("microphone");

        report(
          "Microphone allowed by policy: " +
          policyAllowsMic
        );

      } else {

        report(
          "Permissions policy cannot be inspected."
        );

      }

    } catch (error) {

      report("Policy error: " + error.message);

    }

    report("");
    report("BROWSER PERMISSIONS");
    report("----------------------------");

    let permissionState = "unknown";

    try {

      if (navigator.permissions &&
          navigator.permissions.query) {

        const permission =
          await navigator.permissions.query({
            name: "microphone"
          });

        permissionState = permission.state;

        report(
          "Microphone permission: " +
          permissionState
        );

      } else {

        report("Permission query unavailable.");

      }

    } catch (error) {

      report(
        "Microphone permission query not supported."
      );

    }

    report("");
    report("DETECTED AUDIO DEVICES");
    report("----------------------------");

    try {

      if (navigator.mediaDevices &&
          navigator.mediaDevices.enumerateDevices) {

        const devices =
          await navigator.mediaDevices.enumerateDevices();

        const microphones = devices.filter(
          device => device.kind === "audioinput"
        );

        const outputs = devices.filter(
          device => device.kind === "audiooutput"
        );

        report(
          "Visible microphones: " + microphones.length
        );

        microphones.forEach((device, index) => {

          report(
            "Microphone " + (index + 1) + ": " +
            (device.label || "Name unavailable")
          );

        });

        report(
          "Visible audio outputs: " + outputs.length
        );

        outputs.forEach((device, index) => {

          report(
            "Output " + (index + 1) + ": " +
            (device.label || "Name unavailable")
          );

        });

      } else {

        report("Device detection API unavailable.");

      }

    } catch (error) {

      report(
        "Device enumeration error: " + error.message
      );

    }

    report("");
    report("CONNECTION STATUS");
    report("----------------------------");

    report(
      "Active microphone stream: " +
      !!(stream && stream.active)
    );

    report(
      "OpenAI connection: Not used in this test"
    );

    report("");
    report("CONCLUSION");
    report("----------------------------");

    if (!window.isSecureContext) {

      report(
        "BLOCKED: HTTPS secure connection required."
      );

    } else if (policyAllowsMic === false) {

      report(
        "BLOCKED: The browser permissions policy " +
        "does not allow microphone access."
      );

      report(
        "The parent iframe may be preventing access."
      );

      report(
        "Recommended solution: standalone HTTPS hosting."
      );

    } else if (permissionState === "denied") {

      report(
        "Microphone permission is denied. " +
        "Check Safari permissions and iframe restrictions."
      );

    } else if (stream && stream.active) {

      report(
        "SUCCESS: Microphone access is working."
      );

    } else if (window.self !== window.top) {

      report(
        "Application is running inside an iframe. " +
        "Microphone access may be restricted."
      );

      report(
        "Start the microphone to confirm access."
      );

    } else {

      report(
        "No confirmed policy restriction detected. " +
        "Start the microphone to test."
      );

    }
  }

  window.addEventListener("pagehide", stopMicrophone);

  diagnoseMicrophone();

</script>

</body>
</html>
