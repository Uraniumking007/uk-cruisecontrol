import React, { useEffect, useRef, useState } from "react";
import "./App.css";
import { debugData } from "../utils/debugData";
import { useNuiEvent } from "../hooks/useNuiEvent";
import { fetchNui } from "../utils/fetchNui";

// This will set the NUI to visible if we are
// developing in browser
debugData([
  {
    action: "setVisible",
    data: true,
  },
]);

interface ReturnClientDataCompProps {
  data: unknown;
}

const ReturnClientDataComp: React.FC<ReturnClientDataCompProps> = ({
  data,
}) => (
  <>
    <h5>Returned Data:</h5>
    <pre>
      <code>{JSON.stringify(data, null)}</code>
    </pre>
  </>
);

interface ReturnData {
  x: number;
  y: number;
  z: number;
}

const App: React.FC = () => {
  const [ready, setReady] = useState(false);
  const skipEnabledApply = useRef(false);
  const enabledRef = useRef(false);
  useNuiEvent<boolean>('setCruiseEnabled', (value) => {
    if (enabledRef.current !== value) {
      skipEnabledApply.current = true;
      enabledRef.current = value;
      setEnabled(value);
    }
  });
  // Cruise settings state
  const [enabled, setEnabled] = useState(false);
  const [speed, setSpeed] = useState(60); // will be adjusted to config bounds
  const [limitEnabled, setLimitEnabled] = useState(false);
  const [limitSpeed, setLimitSpeed] = useState(120);
  const [unit, setUnit] = useState<'mph' | 'kmh'>('mph');
  const [minSpeedMph, setMinSpeed] = useState<number>(0);
  const [maxSpeedMph, setMaxSpeed] = useState<number>(300);

  const toMph = (value: number) => unit === 'mph' ? value : value / 1.609344;
  const fromMph = (value: number) => unit === 'mph' ? value : value * 1.609344;
  const minSpeed = fromMph(minSpeedMph);
  const maxSpeed = fromMph(maxSpeedMph);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);

  // Fetch config (unit/min/max) from client once
  useEffect(() => {
    (async () => {
      try {
        const cfg = await fetchNui<{ unit: 'mph' | 'kmh'; minSpeed: number; maxSpeed: number; boundsUnit?: 'mph' | 'kmh'; speed?: number; limitSpeed?: number; limitEnabled?: boolean; enabled?: boolean }>(
          'getCruiseConfig',
          {},
          { unit: 'mph', minSpeed: 0, maxSpeed: 300 }
        );
        const boundsToMph = (v: number) => cfg.boundsUnit === 'kmh' ? v / 1.609344 : v;
        const minimum = boundsToMph(cfg.minSpeed ?? 0);
        const maximum = boundsToMph(cfg.maxSpeed ?? 300);
        setMinSpeed(minimum);
        setMaxSpeed(maximum);
        const display = (mph: number) => cfg.unit === 'kmh' ? mph * 1.609344 : mph;
        const clamp = (value: number) => Math.min(Math.max(display(minimum), value), display(maximum));
        setUnit(cfg.unit);
        setSpeed(clamp(display(cfg.speed ?? 60)));
        setLimitSpeed(clamp(display(cfg.limitSpeed ?? 120)));
        setLimitEnabled(cfg.limitEnabled ?? false);
        enabledRef.current = cfg.enabled ?? false;
        setEnabled(enabledRef.current);
        setReady(true);
      } catch (e) {
        setReady(true);
      }
    })();
  }, []);

  // Basic validation and apply
  const handleApply = async () => {
    // clamp values to sensible ranges
    const clampedSpeed = Math.max(minSpeed, Math.min(maxSpeed, Number(speed)));
    const clampedLimit = Math.max(minSpeed, Math.min(maxSpeed, Number(limitSpeed)));

    // Lua expects MPH; convert if UI is KM/H
    const payload = {
      enabled,
      speed: toMph(clampedSpeed),
      limitEnabled,
      limitSpeed: toMph(clampedLimit),
      unit,
    } as const;

    try {
      const result = await fetchNui<{ ok: boolean; enabled?: boolean; error?: string }>(
        "setCruiseSettings", payload, { ok: true, enabled }
      );
      if (typeof result.enabled === 'boolean' && result.enabled !== enabledRef.current) {
        skipEnabledApply.current = true;
        enabledRef.current = result.enabled;
        setEnabled(result.enabled);
      }
      if (!result.ok) {
        setStatusMessage(result.error || "Failed to apply settings");
        return;
      }
      setStatusMessage("Settings applied");
      // clear status after a short timeout
      setTimeout(() => setStatusMessage(null), 2000);
    } catch (e) {
      console.error("Failed to apply cruise settings", e);
      setStatusMessage("Failed to apply");
      setTimeout(() => setStatusMessage(null), 2000);
    }
  };

  const handleClose = async () => {
    // Tell client to hide the NUI per RegisterNUICallback('hideFrame')
    await fetchNui("hideFrame", {}, {});
  };

  // Debounce apply so we always send fresh state and avoid spamming NUI
  const applyTimeoutRef = useRef<number | null>(null);
  useEffect(() => {
    if (!ready) return;
    if (skipEnabledApply.current) { skipEnabledApply.current = false; return; }
    if (applyTimeoutRef.current) {
      clearTimeout(applyTimeoutRef.current);
    }
    applyTimeoutRef.current = window.setTimeout(() => {
      handleApply();
    }, 200);
    return () => {
      if (applyTimeoutRef.current) {
        clearTimeout(applyTimeoutRef.current);
      }
    };
  }, [enabled, speed, limitEnabled, limitSpeed, unit, ready]);

  return (
    <div className="nui-wrapper">
      <div className="popup-thing sleek">
        <header className="cc-header">
          <h2>Speed Limiter</h2>
        </header>

        <main className="cc-body">
          <section className="section">
            <div className="row header-row">
              <span className="label">Units</span>
              <div className="segmented">
                <button
                  className={"seg-btn" + (unit === 'mph' ? ' active' : '')}
                  onClick={() => {
                    if (unit !== 'mph') {
                      setUnit('mph');
                      setSpeed((s) => toMph(s));
                      setLimitSpeed((s) => toMph(s));
                    }
                  }}
                >
                  MPH
                </button>
                <button
                  className={"seg-btn" + (unit === 'kmh' ? ' active' : '')}
                  onClick={() => {
                    if (unit !== 'kmh') {
                      // convert current values to km/h for display
                      const toKmh = (v: number) => v * 1.609344;
                      setUnit('kmh');
                      setSpeed((s) => toKmh(s));
                      setLimitSpeed((s) => toKmh(s));
                    }
                  }}
                >
                  KM/H
                </button>
              </div>
            </div>
          </section>
          <section className="section">
            <div className="row">
              <label className="toggle">
                <input
                  type="checkbox"
                  checked={enabled}
                  onChange={(e) => {
                    enabledRef.current = e.target.checked;
                    setEnabled(e.target.checked);
                  }}
                />
                <span className="label-text">Enabled</span>
              </label>
            </div>
          </section>

          <section className="section">
            <div className="row header-row">
              <span className="label">Target Speed</span>
              <div className="speed-display" aria-live="polite">
                <span className="speed-value">{Number(speed.toFixed(2))}</span>
                <span className="speed-unit">{unit === 'mph' ? 'mph' : 'km/h'}</span>
              </div>
            </div>
            <div className="row">
              <div className="speed-controls">
                <button
                  className="icon-btn"
                  aria-label="Decrease speed"
                  onClick={() => {
                    setSpeed((s) => Math.max(minSpeed, s - 5));
                  }}
                >
                  −
                </button>
                <input
                  className="slider"
                  type="range"
                  min={minSpeed}
                  max={maxSpeed}
                  value={Number(speed.toFixed(4))}
                  onChange={(e) => setSpeed(Number(e.target.value))}
                />
                <button
                  className="icon-btn"
                  aria-label="Increase speed"
                  onClick={() => {
                    setSpeed((s) => Math.min(maxSpeed, s + 5));
                  }}
                >
                  +
                </button>
                <input
                  className="number-input"
                  type="number"
                  min={minSpeed}
                  max={maxSpeed}
                  value={Number(speed.toFixed(4))}
                  onChange={(e) => {
                    setSpeed(Number(e.target.value));
                  }}
                />
              </div>
            </div>
          </section>

          {/* <section className="section">
            <div className="row">
              <label className="toggle">
                <input
                  type="checkbox"
                  checked={limitEnabled}
                  onChange={(e) => setLimitEnabled(e.target.checked)}
                />
                <span className="label-text">Limit Speed</span>
              </label>
            </div>

            {limitEnabled && (
              <>
                <div className="row header-row">
                  <span className="label">Max Limit</span>
                  <div className="speed-display small">
                    <span className="speed-value">{limitSpeed}</span>
                    <span className="speed-unit">mph</span>
                  </div>
                </div>
                <div className="row">
                  <div className="speed-controls">
                    <button
                      className="icon-btn"
                      aria-label="Decrease limit"
                      onClick={() => {
                        setLimitSpeed((s) => Math.max(0, s - 5));
                        handleApply();
                      }}
                    >
                      −
                    </button>
                    <input
                      className="slider"
                      type="range"
                      min={0}
                      max={300}
                      value={limitSpeed}
                      onChange={(e) => {
                        setLimitSpeed(Number(e.target.value));
                        handleApply();
                      }}
                    />
                    <button
                      className="icon-btn"
                      aria-label="Increase limit"
                      onClick={() => {
                        setLimitSpeed((s) => Math.min(300, s + 5));
                        handleApply();
                      }}
                    >
                      +
                    </button>
                    <input
                      className="number-input"
                      type="number"
                      min={0}
                      max={300}
                      value={limitSpeed}
                      onChange={(e) => {
                        setLimitSpeed(Number(e.target.value));
                        handleApply();
                      }}
                    />
                  </div>
                </div>
              </>
            )}
          </section> */}

          <div className="row actions">
            <button className="btn" onClick={handleClose}>Cancel</button>
          </div>

          {statusMessage && <div className="status">{statusMessage}</div>}
        </main>
      </div>
    </div>
  );
};

export default App;
