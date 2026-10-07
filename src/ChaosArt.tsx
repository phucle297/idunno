/** Decorative vector artwork, not a screenshot or a representation of gameplay. */
export default function ChaosArt({
  variant = 'hero',
  hazards = { meteor: true, flood: false, tornado: false },
}: {
  variant?: 'hero' | 'game'
  hazards?: { meteor: boolean; flood: boolean; tornado: boolean }
}) {
  return (
    <svg
      className={`chaos-art chaos-art--${variant}`}
      viewBox="0 0 600 600"
      fill="none"
      aria-hidden="true"
      focusable="false"
    >
      <g className="chaos-orbit" stroke="currentColor" strokeWidth="1.2">
        <ellipse
          cx="300"
          cy="300"
          rx="245"
          ry="132"
          transform="rotate(-34 300 300)"
        />
        <ellipse
          cx="300"
          cy="300"
          rx="215"
          ry="113"
          transform="rotate(-34 300 300)"
        />
        <ellipse
          cx="300"
          cy="300"
          rx="182"
          ry="94"
          transform="rotate(-34 300 300)"
        />
        <ellipse
          cx="300"
          cy="300"
          rx="147"
          ry="75"
          transform="rotate(-34 300 300)"
        />
        <ellipse
          cx="300"
          cy="300"
          rx="113"
          ry="57"
          transform="rotate(-34 300 300)"
        />
        <path
          d="M89 397C44 313 211 138 406 145M130 424C172 472 376 378 472 231M171 462C260 507 482 359 493 242"
          strokeDasharray="7 7"
          opacity=".55"
        />
      </g>
      {hazards.meteor && (
        <g
          className="meteor hazard-meteor"
          stroke="var(--orange)"
          strokeWidth="2.5"
          strokeLinejoin="round"
        >
          <path d="m439 88-113 146M462 98 359 251M494 96 378 263M455 141 387 249" />
          <path
            d="m332 220 40 9 23 32-8 41-38 23-37-13-20-35 9-35Z"
            fill="var(--background)"
          />
          <path d="m332 220 5 41 35-32M337 261l-25 51M337 261l50 41M337 261l-45 16M337 261l58 0" />
          <path d="m324 237-16 28M371 293l-15 12" opacity=".7" />
        </g>
      )}
      {hazards.tornado && (
        <g
          className="hazard-tornado"
          stroke="var(--lavender)"
          strokeWidth="2.5"
        >
          <g className="tornado-swirl">
            <ellipse
              cx="295"
              cy="213"
              rx="125"
              ry="31"
              transform="rotate(-9 295 213)"
            />
            <ellipse
              cx="307"
              cy="254"
              rx="107"
              ry="27"
              transform="rotate(-9 307 254)"
            />
            <ellipse
              cx="308"
              cy="291"
              rx="84"
              ry="22"
              transform="rotate(-9 308 291)"
            />
            <ellipse
              cx="316"
              cy="327"
              rx="62"
              ry="18"
              transform="rotate(-9 316 327)"
            />
            <ellipse
              cx="327"
              cy="359"
              rx="43"
              ry="14"
              transform="rotate(-9 327 359)"
            />
            <ellipse
              cx="334"
              cy="389"
              rx="23"
              ry="10"
              transform="rotate(-9 334 389)"
            />
            <path
              d="M359 191C455 229 218 270 325 310M263 335c-17 32 89 21 71 68"
              strokeDasharray="5 8"
            />
          </g>
        </g>
      )}
      {hazards.flood && (
        <g className="hazard-flood" stroke="#69cfed" strokeWidth="2">
          <path
            d="M102 401c35-32 73 32 109 0s73 32 109 0 73 32 109 0 73 32 109 0v110H102Z"
            fill="#42b8e814"
            stroke="none"
          />
          <g className="water-lines">
            <path d="M102 401c35-32 73 32 109 0s73 32 109 0 73 32 109 0 73 32 109 0M102 431c35-32 73 32 109 0s73 32 109 0 73 32 109 0 73 32 109 0M102 461c35-32 73 32 109 0s73 32 109 0 73 32 109 0 73 32 109 0" />
            <path
              d="m197 139-7 18m49-2-7 18m173-54-7 18m42 40-7 18m-68-41-7 18"
              opacity=".6"
            />
          </g>
        </g>
      )}
      <g stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round">
        <path d="m122 134 26-16 23 20-10 29-29 2-17-18Z M122 134l22 12 27-8M144 146l-12 23M144 146l17 21" />
        <path d="m453 388 34 7 11 35-27 24-31-16 1-31Z M453 388l13 28 32 14M466 416l5 38M466 416l-26 22" />
        <path d="m219 447 25 6 7 24-20 15-24-17Z M219 447l8 25 24 5M227 472l4 20" />
        <path d="m180 294 17 8-7 17-20-10Z" stroke="var(--orange)" />
        <path d="m401 456 9 5-4 10-11-6Z" stroke="var(--orange)" />
        <path d="M105 241v30m-15-15h30M472 313v24m-12-12h24M343 100v20m-10-10h20" />
        <circle cx="225" cy="129" r="3" />
        <circle cx="112" cy="367" r="3" />
        <circle cx="417" cy="372" r="4" />
        <circle cx="299" cy="465" r="2" />
      </g>
      <path
        d="m480 173 10 27 27 10-27 10-10 27-10-27-27-10 27-10Z"
        fill="var(--orange)"
      />
      <path
        d="m140 428 6 16 16 6-16 6-6 16-6-16-16-6 16-6Z"
        fill="currentColor"
      />
    </svg>
  )
}
