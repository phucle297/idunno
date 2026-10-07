import { useState } from 'react'
import ChaosArt from './ChaosArt'

export default function DisasterArtwork() {
  const [hazards, setHazards] = useState({
    meteor: true,
    flood: false,
    tornado: false,
  })
  const names = { meteor: 'Meteor', flood: 'Flood', tornado: 'Tornado' }
  const active = (Object.keys(names) as (keyof typeof names)[]).filter(
    (name) => hazards[name],
  )

  return (
    <>
      <ChaosArt variant="game" hazards={hazards} />
      <div className="art-controls">
        <div>
          <p className="art-controls-label">TRY A DIFFERENT FORECAST</p>
          <div
            className="hazard-buttons"
            role="group"
            aria-label="Choose artwork effects"
          >
            {(['meteor', 'flood', 'tornado'] as const).map((name) => (
              <button
                type="button"
                key={name}
                className={`hazard-button hazard-button--${name}`}
                aria-pressed={hazards[name]}
                onClick={() =>
                  setHazards((current) => ({
                    ...current,
                    [name]: !current[name],
                  }))
                }
              >
                <span className="hazard-indicator" aria-hidden="true">
                  {hazards[name] ? '+' : '·'}
                </span>
                {names[name]}
              </button>
            ))}
          </div>
        </div>
        <div className="art-status">
          <p role="status" aria-live="polite">
            {active.length
              ? active.map((name) => names[name]).join(' + ')
              : 'Clear skies. For now.'}
          </p>
          <span>Artwork study — not gameplay</span>
        </div>
      </div>
    </>
  )
}
