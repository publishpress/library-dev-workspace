import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  Button,
  ToastStack,
  ConfirmPublishDialog,
  EditionBadge,
  EmptyState,
  PhaseGroup,
  PhaseProgress,
  PublishBoundary,
  StartReleaseDialog,
  StepNavItem,
  TerminalView,
  AutoRunToggle,
  ThemeToggle,
} from './components.jsx';

async function apiGet(path) {
  const res = await fetch(path);
  return res.json();
}

async function apiPost(path, body = {}) {
  const res = await fetch(path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok || data.ok === false) {
    throw new Error(data.error || res.statusText || 'Request failed');
  }
  return data;
}

function isFinished(step) {
  return step.status === 'done' || step.status === 'skipped';
}

function canSkip(step, autoRun) {
  if (!step || step.id === 'github_auth' || step.publish) {
    return false;
  }
  if (step.status === 'done' || step.status === 'skipped' || step.status === 'running') {
    return false;
  }
  if (step.phase === 'Localization') {
    return true;
  }
  if (autoRun || (step.type !== 'auto' && step.type !== 'manual')) {
    return false;
  }
  return true;
}

function canRerun(step) {
  return step?.status === 'done' || step?.status === 'failed' || step?.status === 'skipped';
}

/** Show step note only when it is not already present in the live log. */
function distinctStepNote(note, logLines, isCurrent) {
  if (!note?.trim()) {
    return null;
  }
  const text = note.trim();
  if (!isCurrent || !logLines?.length) {
    return text;
  }
  const blob = logLines.join('\n');
  if (blob.includes(text)) {
    return null;
  }
  for (const line of logLines) {
    const trimmed = line.trim();
    if (trimmed === text || trimmed === `Error: ${text}` || trimmed.endsWith(text)) {
      return null;
    }
  }
  return text;
}

function groupByPhase(steps, currentStepId) {
  const groups = [];
  let current = null;
  for (const step of steps || []) {
    const phase = step.phase || 'Steps';
    if (!current || current.name !== phase) {
      current = { name: phase, steps: [] };
      groups.push(current);
    }
    current.steps.push(step);
  }
  return groups.map((g, i) => ({
    key: `${i}-${g.name}`,
    ...g,
    total: g.steps.length,
    done: g.steps.filter(isFinished).length,
    current: g.steps.some((s) => s.id === currentStepId),
  }));
}

/** CLI form of the current step's action, shown under the panel. */
function cliHint(step) {
  if (step.type === 'confirm') {
    return `run --confirm ${step.id}`;
  }
  if (step.type === 'manual') {
    return `complete ${step.id}`;
  }
  return `run --until ${step.id}`;
}

const STEP_LOG_MARK = /^▶ ([a-z0-9_]+)$/;

/** @param {string[]} lines */
function splitSessionLogByStep(lines) {
  /** @type {Record<string, string[]>} */
  const byStep = {};
  let current = null;
  for (const raw of lines || []) {
    const line = String(raw).replace(/\r$/, '');
    if (!line.trim()) {
      continue;
    }
    const match = line.match(STEP_LOG_MARK);
    if (match) {
      current = match[1];
      if (!byStep[current]) {
        byStep[current] = [];
      }
      byStep[current].push(line);
      continue;
    }
    const key = current ?? '_unassigned';
    if (!byStep[key]) {
      byStep[key] = [];
    }
    byStep[key].push(line);
  }
  return byStep;
}

/** @param {Record<string, string[]>} byStep @param {string} stepId */
function linesForStep(byStep, stepId) {
  return byStep[stepId] ?? [];
}

export default function App() {
  const [status, setStatus] = useState(null);
  const [log, setLog] = useState([]);
  const [busy, setBusy] = useState(false);
  const [startOpen, setStartOpen] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [viewStepId, setViewStepId] = useState(null);
  const [slideDir, setSlideDir] = useState(1);
  const [toasts, setToasts] = useState([]);
  const toastSeq = useRef(0);
  const securityToastKey = useRef(null);
  const [autoRun, setAutoRun] = useState(true);
  const navRef = useRef(null);
  const stepsRef = useRef([]);

  const pushToast = useCallback((toast) => {
    const id = toastSeq.current + 1;
    toastSeq.current = id;
    setToasts((prev) => [{ id, ...toast }, ...prev].slice(0, 4));
  }, []);

  const dismissToast = useCallback((id) => {
    setToasts((prev) => prev.filter((toast) => toast.id !== id));
  }, []);

  const refresh = useCallback(async () => {
    const data = await apiGet('/api/status');
    setStatus(data);
  }, []);

  useEffect(() => {
    refresh();
    // While auto-run holds each finished step (~0.7s), poll fast enough to show it.
    const id = setInterval(refresh, busy ? 400 : 4000);
    return () => clearInterval(id);
  }, [refresh, busy]);

  useEffect(() => {
    const es = new EventSource('/api/events');
    es.onmessage = (ev) => {
      try {
        const { line } = JSON.parse(ev.data);
        setLog((prev) => [...prev, line.replace(/\x1B\[[0-9;]*[A-Za-z]/g, '').replace(/\n$/, '')]);
      } catch {
        /* ignore */
      }
    };
    return () => es.close();
  }, []);

  useEffect(() => {
    if (status?.uiPrefs) {
      setAutoRun(status.uiPrefs.autoRun !== false);
    }
  }, [status?.uiPrefs?.autoRun]);

  const release = status?.release;

  useEffect(() => {
    if (release?.urgency !== 'security' || !release.version) {
      return;
    }
    const key = `${release.version}:${release.edition}`;
    if (securityToastKey.current === key) {
      return;
    }
    securityToastKey.current = key;
    pushToast({
      tone: 'security',
      title: 'Security release',
      message:
        'Keep essential checks. Translations may be skipped. Do not disclose vulnerability details until it is published.',
    });
  }, [release?.urgency, release?.version, release?.edition, pushToast]);
  const steps = status?.steps || [];
  const currentStepId = status?.currentStepId;
  const groups = useMemo(() => groupByPhase(steps, currentStepId), [steps, currentStepId]);
  const currentStep = steps.find((s) => s.id === currentStepId);
  const version = status?.effectiveVersion || release?.version;
  const firstPublishId = steps.find((s) => s.publish)?.id;
  const logByStep = useMemo(() => splitSessionLogByStep(log), [log]);
  stepsRef.current = steps;

  useEffect(() => {
    if (!release?.version) {
      return;
    }
    let cancelled = false;
    (async () => {
      try {
        const data = await apiGet('/api/log');
        if (cancelled || !data.log?.trim()) {
          return;
        }
        const fromFile = data.log
          .replace(/\x1B\[[0-9;]*[A-Za-z]/g, '')
          .split('\n')
          .map((l) => l.replace(/\r$/, ''))
          .filter((l) => l.trim());
        setLog((prev) => (prev.length ? prev : fromFile));
      } catch {
        /* ignore */
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [release?.version]);

  useEffect(() => {
    if (!currentStepId) {
      return;
    }
    setViewStepId((prev) => {
      if (prev && prev !== currentStepId) {
        const list = stepsRef.current;
        const from = list.findIndex((s) => s.id === prev);
        const to = list.findIndex((s) => s.id === currentStepId);
        setSlideDir(to >= from ? 1 : -1);
      }
      return currentStepId;
    });
  }, [currentStepId]);

  useEffect(() => {
    const root = navRef.current;
    if (!root || !currentStepId) {
      return;
    }
    root.querySelector(`[data-step-id="${currentStepId}"]`)?.scrollIntoView({
      block: 'nearest',
      behavior: 'smooth',
    });
  }, [currentStepId]);

  const pickStep = (id) => {
    setViewStepId((prev) => {
      const fromId = prev || currentStepId;
      if (fromId && fromId !== id) {
        const list = stepsRef.current;
        const from = list.findIndex((s) => s.id === fromId);
        const to = list.findIndex((s) => s.id === id);
        setSlideDir(to >= from ? 1 : -1);
      }
      return id;
    });
  };

  const runAction = async (sub, args = [], body = {}) => {
    if (sub === 'start' || sub === 'reset') {
      setLog([]);
    }
    setBusy(true);
    try {
      const data = await apiPost(`/api/${sub}`, { args, ...body });
      await refresh();
      if (data.stopped) {
        return;
      }
    } catch (err) {
      pushToast({ tone: 'failed', title: 'Action failed', message: err.message || 'Request failed' });
    } finally {
      setBusy(false);
    }
  };

  const isRunning = steps.some((s) => s.status === 'running');

  const stopRun = async () => {
    setBusy(true);
    try {
      await apiPost('/api/stop');
      await refresh();
    } catch (err) {
      pushToast({ tone: 'failed', title: 'Action failed', message: err.message || 'Request failed' });
    } finally {
      setBusy(false);
    }
  };

  const toggleAutoRun = async () => {
    const next = !autoRun;
    setAutoRun(next);
    try {
      await apiPost('/api/ui-prefs', { autoRun: next });
      const pendingAuto = currentStep?.type === 'auto' && currentStep.status === 'pending';
      if (next && pendingAuto && !busy && !isRunning) {
        await runAction('run', []);
      }
    } catch (err) {
      setAutoRun(!next);
      pushToast({ tone: 'failed', title: 'Action failed', message: err.message || 'Request failed' });
    }
  };

  const quitRunner = async () => {
    try {
      await apiPost('/api/shutdown');
    } catch {
      /* server may exit before the response completes */
    }
  };

  const terminalActions = (step) => {
    if (!step) {
      return null;
    }
    const isCurrent = step.id === currentStepId;
    const ran = canRerun(step);
    const skippable = isCurrent && canSkip(step, autoRun);
    const running = step.status === 'running';
    const finished = step.status === 'done' || step.status === 'skipped';
    const advanceDisabled = busy || !isCurrent || running || finished;
    const stepIndex = steps.findIndex((s) => s.id === step.id);
    const runLabel = step.publish ? 'Publish…' : !autoRun && stepIndex > 0 ? 'Continue' : 'Run';
    let advanceTitle = 'Run this step';
    if (step.publish) {
      advanceTitle = 'Publish this step';
    } else if (step.status === 'failed') {
      advanceTitle = 'Retry this step';
    } else if (runLabel === 'Continue') {
      advanceTitle = 'Continue from this step';
    }
    if (!isCurrent) {
      advanceTitle = 'Only the current step can run';
    } else if (running) {
      advanceTitle = 'This step is still running';
    } else if (finished) {
      advanceTitle = 'This step is already finished';
    }
    const onAdvance = () => {
      if (step.type === 'confirm' && step.publish) {
        setConfirmOpen(true);
        return;
      }
      if (step.type === 'confirm') {
        runAction('run', ['--confirm', step.id]);
        return;
      }
      if (step.type === 'manual') {
        runAction('complete', [step.id]);
        return;
      }
      runAction('run', []);
    };
    let skipTitle = 'Skip this step';
    if (step.publish || step.id === 'github_auth') {
      skipTitle = 'This step cannot be skipped';
    } else if (!isCurrent) {
      skipTitle = 'Only the current step can be skipped';
    } else if (autoRun && step.phase !== 'Localization') {
      skipTitle = 'Turn auto-run off to skip this step';
    } else if (step.phase === 'Localization') {
      skipTitle = 'Skip the localization phase';
    }
    const againDisabled = busy || running || !ran;
    const advanceVariant = advanceDisabled ? 'secondary' : step.publish ? 'publish' : 'primary';
    const againVariant = !againDisabled && advanceDisabled ? 'primary' : 'secondary';
    return (
      <>
        <Button
          variant={againVariant}
          size="sm"
          icon="play"
          disabled={againDisabled}
          title={ran ? 'Re-execute this step' : 'Available after this step has run'}
          onClick={() => runAction('rerun', [step.id])}
        >
          Run again
        </Button>
        <Button
          variant={advanceVariant}
          size="sm"
          icon={step.publish && !advanceDisabled ? 'lock' : running ? 'spinner' : 'play'}
          disabled={advanceDisabled}
          title={advanceTitle}
          onClick={onAdvance}
        >
          {running ? 'Running…' : runLabel}
        </Button>
        <Button
          variant="secondary"
          size="sm"
          disabled={busy || !skippable}
          title={skipTitle}
          onClick={() => runAction('skip', [step.id])}
        >
          Skip
        </Button>
      </>
    );
  };

  const shownId = viewStepId || currentStepId;
  const shownStep = steps.find((s) => s.id === shownId) || null;
  const shownLines = shownStep ? linesForStep(logByStep, shownStep.id) : [];
  const shownIsCurrent = Boolean(shownStep && shownStep.id === currentStepId);

  const runnerPresets = status?.runnerPresets ?? [];
  const presetMeta = status?.presetMeta ?? {};
  const defaultPreset = status?.defaultPreset ?? runnerPresets[0] ?? '';

  return (
    <div className={release ? 'rr-screen rr-screen--split' : 'rr-screen'}>
      <header className="rr-header">
        <div className="rr-header__top">
          <div className="rr-header__identity">
            <h1 className="rr-header__title">Release Runner</h1>
            <p className="rr-header__sub">Local release checklist for this plugin clone</p>
            {release && (
              <div className="rr-header__facts">
                <p className="rr-header__version">
                  <span>{version}</span>
                  {release.prerelease?.channel && (
                    <span className="rr-header__channel">
                      {release.prerelease.channel}.{release.prerelease.n}
                    </span>
                  )}
                  <EditionBadge product={presetMeta[release.edition]?.product} />
                </p>
                <dl className="rr-facts">
                  <div className="rr-fact">
                    <dt>Preset</dt>
                    <dd>{presetMeta[release.edition]?.label ?? release.edition}</dd>
                  </div>
                  <div className="rr-fact">
                    <dt>Branch</dt>
                    <dd className="rr-fact__mono">{release.branchName}</dd>
                  </div>
                  {status.ghAccount && (
                    <div className="rr-fact">
                      <dt>GitHub</dt>
                      <dd>{status.ghAccount}</dd>
                    </div>
                  )}
                  {release.urgency === 'security' && (
                    <div className="rr-fact rr-fact--alert">
                      <dt>Urgency</dt>
                      <dd>Security</dd>
                    </div>
                  )}
                </dl>
              </div>
            )}
          </div>
          <div className="rr-header__options">
            {release && (isRunning || busy) && (
              <Button variant="danger" size="sm" icon="stop" onClick={stopRun}>
                Stop
              </Button>
            )}
            {release && (
              <Button
                variant="reset"
                size="sm"
                disabled={busy}
                title="Drop this release from the runner. Git history stays as it is."
                onClick={() => runAction('reset', [], { yes: true })}
              >
                Discard release
              </Button>
            )}
            <AutoRunToggle on={autoRun} onChange={toggleAutoRun} />
            <Button
              variant="ghost"
              size="sm"
              icon="power"
              className="rr-icon-btn"
              aria-label="Quit runner"
              title="Quit runner"
              onClick={quitRunner}
            />
            <ThemeToggle onChange={(theme) => apiPost('/api/ui-prefs', { theme })} />
          </div>
        </div>
      </header>

      {status && !release && (
        <EmptyState
          action={
            <Button variant="primary" onClick={() => setStartOpen(true)}>
              Start release
            </Button>
          }
          hint={
            <>
              Or from the terminal: <span className="rr-code">composer release -- start 4.11.0</span>
            </>
          }
        >
          Start a versioned release. Presets come from{' '}
          <span className="rr-code">composer.json</span> →{' '}
          <span className="rr-code">extra.release-presets</span>.
        </EmptyState>
      )}

      {release && (
        <div className="rr-workspace">
          <nav className="rr-nav" ref={navRef} aria-label="Release steps">
            {groups.map((group) => (
              <PhaseGroup key={group.key} name={group.name} done={group.done} total={group.total}>
                {group.steps.map((step) => (
                  <React.Fragment key={step.id}>
                    {step.id === firstPublishId && <PublishBoundary />}
                    <StepNavItem
                      id={step.id}
                      label={step.label}
                      type={step.type}
                      status={step.status}
                      current={step.id === currentStepId}
                      selected={step.id === shownId}
                      onSelect={pickStep}
                    />
                  </React.Fragment>
                ))}
              </PhaseGroup>
            ))}
          </nav>
          <TerminalView
            stepId={shownStep?.id}
            title={shownStep?.label}
            status={shownStep?.status}
            lines={shownLines}
            live={shownIsCurrent && isRunning}
            guide={shownStep?.instructions || shownStep?.message}
            note={
              shownLines.length
                ? null
                : distinctStepNote(shownStep?.note, shownLines, shownIsCurrent)
            }
            cli={shownIsCurrent ? cliHint(shownStep) : null}
            slideDir={slideDir}
            actions={terminalActions(shownStep)}
          />
        </div>
      )}

      {release && steps.length > 0 && (
        <section className="rr-progress-panel" aria-label="Release progress">
          <PhaseProgress phases={groups} />
          <p className="rr-progress-panel__next">
            {currentStep ? (
              <>
                Next: <strong>{currentStep.label}</strong>
              </>
            ) : (
              'All steps complete.'
            )}
          </p>
        </section>
      )}

      <StartReleaseDialog
        open={startOpen}
        onOpenChange={setStartOpen}
        runnerPresets={runnerPresets}
        presetMeta={presetMeta}
        defaultPreset={defaultPreset}
        busy={busy}
        onStart={async ({ version: v, urgency, preset, prereleaseChannel }) => {
          const args = [v, '--urgency', urgency, '--preset', preset];
          if (prereleaseChannel) {
            args.push('--prerelease-channel', prereleaseChannel);
          }
          await runAction('start', args);
          setStartOpen(false);
        }}
      />

      <ToastStack toasts={toasts} onDismiss={dismissToast} />

      <ConfirmPublishDialog
        open={confirmOpen}
        onOpenChange={setConfirmOpen}
        step={currentStep}
        version={version}
        busy={busy}
        onConfirm={async () => {
          setConfirmOpen(false);
          await runAction('run', ['--confirm', currentStep.id]);
        }}
      />
    </div>
  );
}
