export function Header() {
  return (
    <header className="flex items-center justify-between border-b-4 border-wcc-yellow bg-wcc-charcoal px-4 py-3 sm:px-6">
      <div className="rounded-md bg-wcc-white px-2 py-1">
        <img src="/ImpactLab_Logo_HeadsupWelly.png" alt="Heads Up Welly" className="h-9 w-auto sm:h-11" />
      </div>
      <button
        type="button"
        disabled
        title="Login coming soon"
        className="cursor-not-allowed rounded border border-wcc-grey-mid px-3 py-1.5 text-sm font-medium text-wcc-white/70"
      >
        Login
      </button>
    </header>
  )
}
