import { useEffect } from 'react'
import ChaosArt from './ChaosArt'
import DisasterArtwork from './DisasterArtwork'

function BrandMark() {
  return (
    <svg
      className="brand-dot"
      viewBox="0 0 24 24"
      aria-hidden="true"
      focusable="false"
    >
      <path
        d="M12 2v20M2 12h20M5 5l14 14M5 19 19 5"
        fill="none"
        stroke="currentColor"
        strokeWidth="3"
      />
    </svg>
  )
}

function Arrow({ diagonal = false }: { diagonal?: boolean }) {
  return (
    <svg
      width="20"
      height="20"
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
      focusable="false"
    >
      <path
        d={diagonal ? 'M6 18 18 6M6 6h12v12' : 'M4 12h16m-6-6 6 6-6 6'}
        stroke="currentColor"
        strokeWidth="1.7"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  )
}

function Spark({ className = '' }: { className?: string }) {
  return (
    <svg
      className={className}
      width="40"
      height="40"
      viewBox="0 0 40 40"
      aria-hidden="true"
      focusable="false"
    >
      <path
        d="m20 0 5.5 14.5L40 20l-14.5 5.5L20 40l-5.5-14.5L0 20l14.5-5.5Z"
        fill="currentColor"
      />
    </svg>
  )
}

const features = [
  {
    title: 'MULTIPLAYER SURVIVAL',
    text: 'Survive alongside — or against — other players.',
    icon: 'players',
  },
  {
    title: 'INTERACTING DISASTERS',
    text: 'Disasters can combine and influence each other, creating unexpected situations.',
    icon: 'disasters',
  },
  {
    title: 'PHYSICS & CHAOS',
    text: 'The environment and physics are part of the challenge.',
    icon: 'physics',
  },
  {
    title: 'EVERY ROUND IS DIFFERENT',
    text: 'Different combinations of disasters create unpredictable matches.',
    icon: 'rounds',
  },
]

function FeatureIcon({ icon }: { icon: string }) {
  return (
    <svg
      width="32"
      height="32"
      viewBox="0 0 32 32"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      {icon === 'players' && (
        <>
          <circle cx="12" cy="10" r="4" />
          <path d="M4 27v-4a8 8 0 0 1 16 0v4M22 6a4 4 0 0 1 0 8m3 5a7 7 0 0 1 3 6v2" />
        </>
      )}
      {icon === 'disasters' && (
        <>
          <path d="m17 3-9 14h7l-2 12 11-17h-8l1-9Z" />
          <path d="m3 8 3 3M26 23l3 3M25 5l-3 3M5 25l3-3" />
        </>
      )}
      {icon === 'physics' && (
        <>
          <path d="m16 3 12 7v14l-12 7-12-7V10Z M4 10l12 7 12-7M16 17v14" />
          <path d="m22 2 6 3M1 25l6 4" />
        </>
      )}
      {icon === 'rounds' && (
        <>
          <path d="M26 12A11 11 0 0 0 6 8L3 12m0-7v7h7M6 20a11 11 0 0 0 20 4l3-4m0 7v-7h-7" />
          <path d="m16 10 2 4 4 2-4 2-2 4-2-4-4-2 4-2Z" />
        </>
      )}
    </svg>
  )
}

export default function App() {
  useEffect(() => {
    // Content stays visible if motion is disabled or the observer is unavailable.
    if (
      window.matchMedia('(prefers-reduced-motion: reduce)').matches ||
      !('IntersectionObserver' in window)
    )
      return
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (
            !entry.isIntersecting ||
            window.matchMedia('(prefers-reduced-motion: reduce)').matches
          )
            return
          entry.target.animate(
            [
              { opacity: 0.55, transform: 'translateY(18px)' },
              { opacity: 1, transform: 'translateY(0)' },
            ],
            { duration: 550, easing: 'cubic-bezier(.2,.7,.2,1)' },
          )
          observer.unobserve(entry.target)
        })
      },
      { threshold: 0.08 },
    )
    document
      .querySelectorAll('[data-reveal]')
      .forEach((element) => observer.observe(element))
    return () => observer.disconnect()
  }, [])

  return (
    <>
      <a className="skip-link" href="#main">
        Skip to content
      </a>
      <header className="site-header container flex items-center justify-between">
        <a className="wordmark" href="#top" aria-label="Permees home">
          PERMEES
          <BrandMark />
        </a>
        <nav
          aria-label="Main navigation"
          className="flex items-center gap-6 sm:gap-10"
        >
          <a href="#games">Games</a>
          <a href="#about">About</a>
          <a href="#contact">
            Contact <span aria-hidden="true">↗</span>
          </a>
        </nav>
      </header>

      <main id="main" tabIndex={-1}>
        <section
          id="top"
          className="hero container"
          aria-labelledby="hero-title"
          onPointerMove={(event) => {
            if (
              event.pointerType !== 'mouse' ||
              window.matchMedia('(prefers-reduced-motion: reduce)').matches
            )
              return
            const bounds = event.currentTarget.getBoundingClientRect()
            event.currentTarget.style.setProperty(
              '--pointer-x',
              `${((event.clientX - bounds.left) / bounds.width - 0.5) * 18}px`,
            )
            event.currentTarget.style.setProperty(
              '--pointer-y',
              `${((event.clientY - bounds.top) / bounds.height - 0.5) * 14}px`,
            )
          }}
          onPointerLeave={(event) => {
            event.currentTarget.style.setProperty('--pointer-x', '0px')
            event.currentTarget.style.setProperty('--pointer-y', '0px')
          }}
        >
          <div className="hero-copy">
            <p className="eyebrow">
              <span className="little-cross" aria-hidden="true">
                +
              </span>{' '}
              INDEPENDENT GAMES. UNEXPECTED MOMENTS.
            </p>
            <h1 id="hero-title">
              WE MAKE <span className="orange">CHAOS</span> FUN.
            </h1>
            <p className="hero-description">
              Permees is an independent game studio creating playful multiplayer
              experiences built around unpredictable interactions, physics, and
              chaos.
            </p>
            <a className="button" href="#games">
              Discover Disaster Party <Arrow />
            </a>
            <p className="hero-status">
              <span className="status-dot" />
              Currently in development
            </p>
          </div>
          <div className="hero-visual" aria-hidden="true">
            <div className="orbit-caption">
              A LITTLE UNPREDICTABLE. BY DESIGN.
            </div>
            <ChaosArt />
            <div className="indie-sticker">
              INDEPENDENT
              <br />
              BY DESIGN.
              <Spark />
            </div>
          </div>
          <div className="hero-bottom flex items-center justify-between">
            <span>SMALL STUDIO. NO SMALL IDEAS.</span>
            <a href="#games">
              MEET OUR FIRST GAME <span aria-hidden="true">↓</span>
            </a>
          </div>
        </section>

        <section
          id="games"
          className="games container section-space"
          aria-labelledby="game-title"
        >
          <div className="section-label flex items-center justify-between">
            <p className="eyebrow">
              <span className="orange">01 /</span> OUR FIRST GAME
            </p>
            <span className="badge">
              <span className="status-dot" />
              IN DEVELOPMENT
            </span>
          </div>
          <div className="game-heading" data-reveal>
            <h2 id="game-title">
              DISASTER <span>PARTY</span>
            </h2>
            <p>
              Survive the chaos.
              <br />
              <span>Be the last one standing.</span>
            </p>
          </div>

          {/* Replace this figure with real key art, screenshots or a video once supplied. */}
          <figure
            className="game-media"
            data-reveal
            aria-label="Decorative Disaster Party artwork. Gameplay footage and screenshots will be added here later."
          >
            <div className="media-topline">
              <span>
                <span className="orange">✳</span> DISASTER PARTY
              </span>
              <span>MULTIPLAYER DISASTER SURVIVAL</span>
            </div>
            <div className="media-grid" aria-hidden="true" />
            <DisasterArtwork />
            <div className="media-poster" aria-hidden="true">
              BAD WEATHER.
              <br />
              GOOD COMPANY<span>.</span>
            </div>
            <figcaption className="media-caption">
              <span className="media-caption-title">
                <span className="capture-icon" aria-hidden="true" />
                GAMEPLAY FOOTAGE & SCREENSHOTS
              </span>
              <span>Coming later</span>
            </figcaption>
          </figure>

          <div className="game-story" data-reveal>
            <div>
              <p className="eyebrow">ONE ROUND. A PERFECT STORM.</p>
              <h3>
                STAY SHARP.
                <br />
                <span className="lavender">STAY STANDING.</span>
              </h3>
            </div>
            <div className="game-description">
              <p>
                Disaster Party is a multiplayer disaster survival game where
                players compete to survive continuously summoned disasters.
              </p>
              <p>
                Meteor showers, floods, tornadoes, and other disasters can
                appear together and interact with both the environment and each
                other, creating unpredictable situations every round.
              </p>
              <p>
                Players must adapt, use the environment, and survive the chaos.
                The last player standing wins.
              </p>
              <p className="steam-target">
                <span aria-hidden="true">✳</span>
                <span>Targeting Steam Early Access</span>
              </p>
            </div>
          </div>

          <div
            className="features grid sm:grid-cols-2 lg:grid-cols-4"
            data-reveal
          >
            {features.map((feature, i) => (
              <article className="feature" key={feature.title}>
                <div className="feature-top flex items-center justify-between">
                  <FeatureIcon icon={feature.icon} />
                  <span>0{i + 1}</span>
                </div>
                <h3>{feature.title}</h3>
                <p>{feature.text}</p>
              </article>
            ))}
          </div>
        </section>

        <section
          id="about"
          className="about section-space"
          aria-labelledby="about-title"
        >
          <div className="container about-grid" data-reveal>
            <div>
              <p className="eyebrow">
                <span className="lavender">02 /</span> THE STUDIO
              </p>
              <h2 id="about-title">
                SMALL TEAM.
                <br />
                <span className="lavender">BIG CHAOS.</span>
              </h2>
            </div>
            <div className="about-copy">
              <Spark className="about-spark" />
              <p>
                Permees is an independent game studio focused on creating games
                driven by interaction, emergent gameplay, and memorable moments
                between players.
              </p>
              <p>
                We&apos;re currently building our first title,{' '}
                <span className="cream">Disaster Party.</span>
              </p>
            </div>
          </div>
        </section>

        <section
          className="development container"
          aria-labelledby="development-title"
          data-reveal
        >
          <div className="development-label">
            <span className="status-dot" />
            <h2 id="development-title">CURRENTLY BUILDING</h2>
          </div>
          <dl className="development-grid">
            <div>
              <dt className="sr-only">Game</dt>
              <dd className="development-game">Disaster Party</dd>
              <dd>Multiplayer disaster survival game</dd>
            </div>
            <div>
              <dt>Current stage</dt>
              <dd>
                <span className="lavender">Active development</span>
              </dd>
            </div>
            <div>
              <dt>Target</dt>
              <dd>Playable Steam Early Access</dd>
            </div>
          </dl>
        </section>

        <section
          id="contact"
          className="contact container section-space"
          aria-labelledby="contact-title"
          data-reveal
        >
          <p className="eyebrow">
            <span className="orange">03 /</span> SAY HELLO
          </p>
          <div className="contact-heading flex items-center justify-between">
            <h2 id="contact-title">
              LET&apos;S TALK<span className="orange">.</span>
            </h2>
            <Spark />
          </div>
          <p>For business, collaboration, or general inquiries:</p>
          <a className="email-link" href="mailto:support@permees.com">
            support@permees.com <Arrow diagonal />
          </a>
        </section>
      </main>

      <footer className="container site-footer flex flex-col gap-6 sm:flex-row sm:items-center sm:justify-between">
        <div className="footer-brand">
          <a href="#top" className="wordmark" aria-label="Permees home">
            PERMEES
            <BrandMark />
          </a>
          <span>Independent Game Studio</span>
        </div>
        <p>© 2026 Permees. All rights reserved.</p>
        <button
          className="back-top"
          type="button"
          onClick={() => window.scrollTo(0, 0)}
        >
          BACK TO TOP <span aria-hidden="true">↑</span>
        </button>
      </footer>
    </>
  )
}
