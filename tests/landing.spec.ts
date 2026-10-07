import { expect, test } from '@playwright/test'

test('visitors can discover the game and contact the studio without dead links', async ({
  page,
}) => {
  const errors: string[] = []
  page.on('pageerror', (error) => errors.push(error.message))
  await page.goto('/')
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(
    'WE MAKE CHAOS FUN.',
  )
  await page.getByRole('link', { name: 'Discover Disaster Party' }).click()
  await expect(page).toHaveURL(/#games$/)
  await expect(
    page.getByRole('heading', { name: 'DISASTER PARTY', exact: true }),
  ).toBeInViewport()
  await expect(
    page.getByText('Targeting Steam Early Access', { exact: true }),
  ).toBeVisible()
  await expect(
    page.getByRole('link', { name: /steam|wishlist|discord/i }),
  ).toHaveCount(0)
  await page
    .getByRole('navigation')
    .getByRole('link', { name: 'About' })
    .click()
  await expect(page).toHaveURL(/#about$/)
  await page
    .getByRole('navigation')
    .getByRole('link', { name: 'Contact' })
    .click()
  await expect(page).toHaveURL(/#contact$/)
  await expect(
    page.getByRole('link', { name: /support@permees.com/ }),
  ).toHaveAttribute('href', 'mailto:support@permees.com')
  const contactUrl = page.url()
  const historyLength = await page.evaluate(() => history.length)
  await page.getByRole('button', { name: 'Back to top' }).click()
  await expect.poll(() => page.evaluate(() => window.scrollY)).toBe(0)
  expect(await page.evaluate(() => window.scrollX)).toBe(0)
  expect(page.url()).toBe(contactUrl)
  expect(await page.evaluate(() => history.length)).toBe(historyLength)
  for (const link of await page.locator('a[href^="#"]').all()) {
    const target = await link.getAttribute('href')
    expect(target).not.toBe('#')
    await expect(page.locator(target!)).toHaveCount(1)
  }
  expect(errors).toEqual([])
})

test('static metadata, small screens, keyboard access and reduced motion are supported', async ({
  page,
  request,
}) => {
  const html = await (await request.get('/')).text()
  expect(html).toContain('<title>Permees — Independent Game Studio</title>')
  expect(html).toContain('https://permees.com/')
  expect(html).toContain('property="og:image"')
  await page.emulateMedia({ reducedMotion: 'reduce' })
  await page.goto('/')
  await expect(page.getByRole('link', { name: 'Skip to content' })).toBeAttached()
  await page.keyboard.press('Tab')
  await expect(
    page.getByRole('link', { name: 'Skip to content' }),
  ).toBeFocused()
  await page.keyboard.press('Enter')
  await expect(page.locator('main')).toBeFocused()
  for (const width of [320, 390, 768, 1440]) {
    await page.setViewportSize({ width, height: 900 })
    await page.evaluate(() => document.fonts.ready)
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= window.innerWidth,
      ),
    ).toBe(true)
  }
  await expect(
    page.getByRole('heading', { name: 'SMALL TEAM. BIG CHAOS.' }),
  ).toBeVisible()
  expect(
    await page
      .locator('.chaos-orbit')
      .evaluateAll((elements) =>
        elements.every(
          (element) => getComputedStyle(element).animationName === 'none',
        ),
      ),
  ).toBe(true)
})

test('the static build has real share assets and no external runtime requests', async ({
  page,
  request,
}) => {
  const externalRequests: string[] = []
  const failedAssets: string[] = []
  page.on('request', (req) => {
    if (new URL(req.url()).origin !== 'http://127.0.0.1:4173')
      externalRequests.push(req.url())
  })
  page.on('response', (response) => {
    if (response.status() >= 400) failedAssets.push(response.url())
  })
  await page.goto('/')
  await page.evaluate(() => document.fonts.ready)
  await expect(page.locator('.features article')).toHaveCount(4)
  await expect(
    page.getByRole('heading', { name: 'INTERACTING DISASTERS', exact: true }),
  ).toBeVisible()
  await expect(
    page.getByText('Active development', { exact: true }),
  ).toBeVisible()
  await expect(page.locator('.game-media')).toHaveAccessibleName(
    /Decorative.*Gameplay footage.*later/,
  )
  const image = await request.get('/og-image.png')
  expect(image.status()).toBe(200)
  expect(image.headers()['content-type']).toContain('image/png')
  const bytes = await image.body()
  expect(bytes.readUInt32BE(16)).toBe(1200)
  expect(bytes.readUInt32BE(20)).toBe(630)
  expect(await (await request.get('/robots.txt')).text()).toContain(
    'Sitemap: https://permees.com/sitemap.xml',
  )
  expect(await (await request.get('/sitemap.xml')).text()).toContain(
    '<loc>https://permees.com/</loc>',
  )
  expect(externalRequests).toEqual([])
  expect(failedAssets).toEqual([])
})

test('disaster artwork toggles combine independently and work with keyboard and reduced motion', async ({
  page,
}) => {
  await page.emulateMedia({ reducedMotion: 'reduce' })
  await page.goto('/')
  const meteor = page.getByRole('button', { name: 'Meteor', exact: true })
  const flood = page.getByRole('button', { name: 'Flood', exact: true })
  const tornado = page.getByRole('button', { name: 'Tornado', exact: true })
  await expect(meteor).toHaveAttribute('aria-pressed', 'true')
  await expect(flood).toHaveAttribute('aria-pressed', 'false')
  await flood.focus()
  await page.keyboard.press('Space')
  await expect(flood).toHaveAttribute('aria-pressed', 'true')
  await expect(meteor).toHaveAttribute('aria-pressed', 'true')
  await expect(page.locator('.chaos-art--game .hazard-flood')).toHaveCount(1)
  await tornado.click()
  await expect(page.getByRole('status')).toHaveText('Meteor + Flood + Tornado')
  await expect(page.locator('.chaos-art--game .hazard-tornado')).toHaveCount(1)
  await meteor.click()
  await expect(page.locator('.chaos-art--game .hazard-meteor')).toHaveCount(0)
  await expect(page.locator('.chaos-art--game .hazard-flood')).toHaveCount(1)
  await flood.click()
  await tornado.click()
  await expect(page.getByRole('status')).toHaveText('Clear skies. For now.')
  await meteor.click()
  await expect(page.locator('.chaos-art--game .hazard-meteor')).toHaveCount(1)
  await expect(page.getByText('Artwork study — not gameplay')).toBeVisible()
  expect(
    await page
      .locator('.chaos-art--game .hazard-meteor')
      .evaluate((element) => getComputedStyle(element).animationName),
  ).toBe('none')
  for (const width of [320, 390, 768, 1440]) {
    await page.setViewportSize({ width, height: 900 })
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= innerWidth,
      ),
    ).toBe(true)
  }
})

test('pointer artwork responds in both directions but stops for reduced motion', async ({
  page,
}) => {
  await page.setViewportSize({ width: 1440, height: 1000 })
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await page.goto('/')
  const hero = page.locator('.hero')
  const box = (await hero.boundingBox())!
  await page.mouse.move(box.x + box.width * 0.85, box.y + box.height * 0.5)
  await expect
    .poll(async () =>
      Number.parseFloat(
        await hero.evaluate((element) =>
          element.style.getPropertyValue('--pointer-x'),
        ),
      ),
    )
    .toBeGreaterThan(0)
  await page.mouse.move(box.x + box.width * 0.15, box.y + box.height * 0.5)
  await expect
    .poll(async () =>
      Number.parseFloat(
        await hero.evaluate((element) =>
          element.style.getPropertyValue('--pointer-x'),
        ),
      ),
    )
    .toBeLessThan(0)
  await page.getByRole('button', { name: 'Flood', exact: true }).click()
  expect(
    await page
      .locator('.hazard-flood')
      .evaluate((element) => getComputedStyle(element).animationName),
  ).toBe('flood-rise')
  await page.emulateMedia({ reducedMotion: 'reduce' })
  expect(
    await page
      .locator('.hazard-flood')
      .evaluate((element) => getComputedStyle(element).animationName),
  ).toBe('none')
  const reducedTransform = await page
    .locator('.chaos-art--hero')
    .evaluate((element) => getComputedStyle(element).transform)
  await page.locator('.hero').scrollIntoViewIfNeeded()
  await page.mouse.move(box.x + box.width * 0.9, box.y + box.height * 0.4)
  expect(
    await page
      .locator('.chaos-art--hero')
      .evaluate((element) => getComputedStyle(element).transform),
  ).toBe(reducedTransform)
})
