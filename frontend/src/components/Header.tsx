export function Header() {
  return (
    <header className="flex items-center justify-between border-b-4 border-wcc-yellow bg-wcc-charcoal px-4 py-3 sm:px-6">
      <h1 className="text-xl font-bold tracking-tight text-wcc-white sm:text-2xl">
        Welly <span className="text-wcc-yellow">Alerts</span>
      </h1>
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
