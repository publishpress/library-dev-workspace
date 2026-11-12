A full-width message for release-level conditions: security urgency, waiting on an external sign-in, or a failed run.

**Provide:** `tone` (`security` · `waiting` · `failed`), `title`, and `children` as one or two sentences.

- Do not put these in the header. The app shows them as toasts: fixed at the bottom right, gone after 5 seconds, and dismissible. Hover or focus pauses the timer. The security urgency pill stays in the header.
- Don't use it for step instructions; those belong in the current `StepRow`'s `guide`.
