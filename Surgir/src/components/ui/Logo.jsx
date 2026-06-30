/**
 * Logo SURGIR — Financiera / Fuerza de Ventas.
 */
export default function Logo({
  size = 44,
  wordmark = true,
  variant = 'dark',
  subtitle = 'FUERZA DE VENTAS',
}) {
  const textColor = variant === 'light' ? '#ffffff' : '#e30613'
  const subColor = variant === 'light' ? 'rgba(255,255,255,.85)' : '#5c6370'
  const nameSize = Math.round(size * 0.52)
  const subSize = Math.max(9, Math.round(size * 0.22))

  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 12 }}>
      <svg
        width={size}
        height={size}
        viewBox="0 0 48 48"
        xmlns="http://www.w3.org/2000/svg"
        aria-label="SURGIR"
        role="img"
      >
        <rect x="2" y="2" width="44" height="44" rx="12" fill="#e30613" />
        <path
          d="M14 32V16h8.5c4.2 0 7 2.4 7 6.1 0 2.5-1.2 4.3-3.2 5.1L30 32h-4.8l-3.4-4.2H18.2V32H14zm4.2-8.2h4c1.8 0 2.8-1 2.8-2.4S24 19 22.2 19h-4v4.8z"
          fill="#fff"
        />
        <circle cx="36" cy="12" r="5" fill="#ffc20e" />
      </svg>

      {wordmark && (
        <span style={{ display: 'flex', flexDirection: 'column', lineHeight: 1.04 }}>
          <span style={{ fontWeight: 800, fontSize: nameSize, color: textColor, letterSpacing: '0.5px' }}>
            SURGIR
          </span>
          {subtitle && (
            <span style={{ fontSize: subSize, fontWeight: 700, color: subColor, letterSpacing: '1.2px' }}>
              {subtitle}
            </span>
          )}
        </span>
      )}
    </span>
  )
}
