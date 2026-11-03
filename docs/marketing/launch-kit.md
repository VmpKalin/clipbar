# ClipBar launch kit

Everything needed to put ClipBar in front of people: positioning, copy for each channel, the image set, and the steps that must happen before a public release.

## Positioning

**One-liner:** Your clipboard, supercharged. Everything you copy, everything you paste, one keystroke away in the Mac menu bar.

**Short (140 chars):** ClipBar is a Liquid Glass clipboard manager for Mac: history, snippets, contacts and smart tools in one menu bar panel. ⇧⌘V.

**Who it's for**
- Developers: commands, JSON, paths, API keys (masked), Finder and Terminal from a path.
- Designers: colors with previews, screenshots with OCR, background removal, QR codes.
- Anyone who types the same email, address, IBAN or reply ten times a day.

**Why not just Maccy / Raycast / Paste?**

| | ClipBar | Maccy | Paste | Raycast clipboard |
| --- | --- | --- | --- | --- |
| Menu bar panel, keyboard-first | ✅ | ✅ | ❌ (bottom drawer) | ❌ (launcher) |
| Snippet library with keywords and dynamic tokens | ✅ | ❌ | partial | separate feature |
| Contacts in the same search | ✅ | ❌ | ❌ | ❌ |
| Image tools (OCR, QR, background removal) | ✅ | ❌ | ❌ | partial |
| Transforms before paste (JSON, case, Base64, calculator…) | ✅ | ❌ | ❌ | partial |
| Secrets masked and auto-expired | ✅ | ❌ | ❌ | ❌ |
| Fully local, no account | ✅ | ✅ | ❌ (iCloud) | ✅ |

Check the competitor columns before publishing. They change often.

## Image set

All images are in `docs/promo` (2880×1800, 16:10, fits Product Hunt, X and Mac App Store):

1. `01-hero.jpg`: Your clipboard, supercharged.
2. `02-quick-search.jpg`: One search box for everything.
3. `03-library.jpg`: The things you type every day.
4. `04-dynamic.jpg`: Snippets that fill themselves in.
5. `05-images.jpg`: Screenshots that do more.
6. `06-files.jpg`: Any path, straight to Finder or Terminal.
7. `07-colors.jpg`: It knows what you copied.
8. `08-privacy.jpg`: Secrets stay secret.

Regenerate them with `--snapshot` and `scripts/make-promo.swift` (see README).

**Still missing (record by hand):** a 20 to 30 second screen recording. Copy a few things, press ⇧⌘V, search, paste with ⌥↩, then use a snippet. That video does more than any screenshot on Product Hunt and X.

## Copy per channel

### Product Hunt

**Name:** ClipBar
**Tagline (60):** Your clipboard, supercharged — right in the Mac menu bar
**Topics:** Mac, Productivity, Developer Tools

**Description:**
> ClipBar keeps everything you copy (text, links, files, images, colors, code) and puts it one keystroke away in a Liquid Glass panel under the menu bar. One search box finds clips, your saved snippets and your contacts. Paste straight into the app you were in, or transform first: OCR an image, pretty-print JSON, change case, calculate. Secrets are masked and expire. Everything stays on your Mac.

**First comment (maker):**
> Hi PH 👋 I built ClipBar because I kept retyping the same email, IBAN and address, and kept losing that one command I copied an hour ago. Maccy inspired it. I wanted the same speed plus a library of things I paste every day, contacts in the same search, and small tools such as OCR and JSON formatting right before pasting. It's keyboard-first: ⇧⌘V, type, ↩. I'd love to hear what you paste most often. That's what goes into the next version.

### Show HN

**Title:** Show HN: ClipBar – a menu bar clipboard manager with snippets, contacts and OCR

> I've been using Maccy for years and wanted a bit more: a snippet library (with {date}/{uuid} tokens), contacts in the same search, and quick actions on what I copied (OCR, QR, background removal via Vision, JSON pretty-print, Base64, a small calculator). ClipBar is native SwiftUI/AppKit with SwiftData, fully local, and masks API keys it detects (OpenAI, Anthropic, GitHub, AWS, Stripe, JWT…) with auto-expiry. Concealed/transient pasteboard types from password managers are never stored. Feedback on the UX and the privacy defaults is very welcome.

### Reddit: r/macapps, r/MacOS, r/productivity

**Title:** I made ClipBar, a Liquid Glass clipboard manager for the menu bar (history + snippets + contacts in one search)

> ⇧⌘V opens a panel under the menu bar icon. Everything you've copied is there, grouped by type (images, links, files, code, colors), plus a Library of things you paste often and your contacts. Keyboard-first, fully local, no account. Screenshots below. Happy to answer questions and take feature requests.

Post with the hero image and 3 to 4 slides as a gallery. r/macapps requires a flair and price info.

### X / Threads thread

1. Your clipboard, supercharged. Meet ClipBar, a Liquid Glass clipboard manager for the Mac menu bar. ⇧⌘V 🧵 [01-hero]
2. One search box for history, saved snippets and contacts. Filters like `app:figma` or `is:image`. [02]
3. A Library for the things you type daily: emails, addresses, IBANs, replies. Keywords like `@mail`. [03]
4. Dynamic snippets: {date}, {time}, {uuid}, {clipboard}. Always fresh. [04]
5. Copied a screenshot? Copy its text, scan its QR code or remove the background. [05]
6. Copy a path → open it in Finder or a Terminal right there. [06]
7. API keys are masked and auto-expire. Password managers are ignored. Nothing leaves your Mac. [08]
8. Want early access? Reply or DM. 🙌

### Ukrainian channels (DOU, Telegram, LinkedIn)

> Зробив ClipBar, менеджер буфера обміну для Mac у стилі Liquid Glass. ⇧⌘V відкриває панель під іконкою в menu bar. Там є все, що ви копіювали (текст, посилання, файли, картинки, кольори, код), бібліотека фраз і даних, які вставляєте щодня (email, адреса, IBAN, шаблони з {date} та {uuid}), і контакти. Усе знаходиться через один пошук.
>
> Бонусом є дії перед вставкою: OCR з картинки, QR-коди, видалення фону, форматування JSON, Base64, калькулятор. API-ключі маскуються й самі видаляються, а дані нікуди не йдуть з вашого Mac. Шукаю перших тестувальників, пишіть.

## Where to post (in order)

1. Friends and colleagues as a TestFlight-style beta: a notarized DMG plus a feedback form. Fix the top complaints.
2. Telegram and LinkedIn in your own network, then DOU.
3. r/macapps (Tuesday to Thursday, morning US time).
4. Show HN, a weekday at 8 to 10 am Pacific time.
5. Product Hunt, launching at 00:01 PT on a Tuesday. Line up 10 or more people to comment on day one.
6. Mac newsletters and sites that review indie Mac apps (MacStories, 9to5Mac tips, Setapp's "apps we like"), plus the awesome-mac and open-source-mac-os-apps lists on GitHub if you go open source.

## Before a public release

These block distribution to other people. The current build is signed with an Apple Development certificate and only runs reliably on this Mac.

- [ ] **Developer ID + notarization.** The pipeline is ready (`scripts/release.sh`, hardened runtime on). What's left is the one-time setup in [docs/release.md](../release.md): a Developer ID certificate and notary credentials.
- [ ] **Updates.** Add Sparkle (appcast on GitHub Releases) so testers get fixes.
- [ ] **Onboarding.** Make the first launch explain ⇧⌘V and ask for Accessibility (for paste) with one clear screen.
- [ ] **Landing page.** One page with the hero, 4 slides, the video, a download button and an email field. GitHub Pages or Framer is enough.
- [ ] **Privacy policy.** A short one: no data collection, everything local.
- [ ] **Bundle ID and name check.** Search the App Store and trademarks for "ClipBar" before spending on promo. Rename now if needed. It is cheap today and expensive later.
- [ ] **Business model.** Pick one before launch:
  - Free while in beta, then a paid license (one-time $9 to $15 is common for menu bar utilities).
  - Free core with a Pro tier (Library sync, image tools, transforms).
  - Open source plus donations or GitHub Sponsors, which helps reach on HN and Reddit.
- [ ] **Mac App Store (optional).** It needs App Sandbox, so CGEvent paste and some file actions have to be reworked. Direct distribution first is simpler.
- [ ] **Feedback loop.** An email address plus GitHub Issues, and a "Send feedback" item in the status menu.
