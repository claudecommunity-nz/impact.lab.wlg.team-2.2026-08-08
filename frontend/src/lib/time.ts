export function formatAge(iso: string): string {
  const seconds = Math.max(0, Math.floor((Date.now() - new Date(iso).getTime()) / 1000))
  if (seconds < 60) return `${seconds}s ago`
  const minutes = Math.floor(seconds / 60)
  if (minutes < 60) return `${minutes} min ago`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `${hours}h ago`
  const days = Math.floor(hours / 24)
  return `${days}d ago`
}

export function formatUntil(iso: string): string {
  const date = new Date(iso)
  const time = date.toLocaleTimeString('en-NZ', { hour: 'numeric', minute: '2-digit' })
  const now = new Date()
  const startOfDay = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
  const dayDiff = Math.round((startOfDay(date) - startOfDay(now)) / 86_400_000)

  if (dayDiff === 0) return `until ${time} today`
  if (dayDiff === 1) return `until ${time} tomorrow`
  return `until ${time}, ${date.toLocaleDateString('en-NZ', { weekday: 'short', day: 'numeric', month: 'short' })}`
}
