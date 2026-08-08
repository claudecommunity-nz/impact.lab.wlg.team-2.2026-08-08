import { useEffect, useState } from 'react'

const STORAGE_KEY = 'wellyalerts.demoMode'

interface DemoModeState {
  enabled: boolean
  scenarioId: string | null
  pointId: string | null
}

const DEFAULT_STATE: DemoModeState = { enabled: false, scenarioId: null, pointId: null }

function load(): DemoModeState {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return DEFAULT_STATE
    return { ...DEFAULT_STATE, ...(JSON.parse(raw) as Partial<DemoModeState>) }
  } catch {
    return DEFAULT_STATE
  }
}

export function useDemoMode() {
  const [state, setState] = useState<DemoModeState>(load)

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state))
  }, [state])

  function setEnabled(enabled: boolean) {
    setState((prev) => ({ ...prev, enabled }))
  }

  function setSelection(scenarioId: string, pointId: string) {
    setState((prev) => ({ ...prev, scenarioId, pointId }))
  }

  return { ...state, setEnabled, setSelection }
}
