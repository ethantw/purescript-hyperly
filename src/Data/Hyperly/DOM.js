// Used internally to gate `windowEffect` between the browser path (use the
// global `window`) and the server path (lazily import happy-dom). Not exposed
// to PureScript callers — context detection lives entirely in JS.
const isBrowserSide = typeof window === 'object'

export const windowEffect =
  isBrowserSide
  ? () => window

  : await (async () => {
      const { Window } = await import('happy-dom')
      const window = new Window({
        settings: {
          disableJavaScriptEvaluation: true,
          disableJavaScriptFileLoading: true,
          disableComputedStyleRendering: true,
          disableCSSFileLoading: true,
          disableIframePageLoading: true,
        },
      })
      return () => window
    }) ()

const withHTML = html => /<html\b.*>/i.test(html)
const withHeadOrBody = html => /<(head|body)\b.*>/i.test(html)

const withBodyOnly = html => {
  const trimmed = html.trim()
  return /^<(body)\b.*>/i.test(trimmed) && /<\/body>$/i.test(trimmed)
}

export const createHTMLHolder =
  html =>
  () =>
{
  try {
    const doc = windowEffect().document.implementation.createHTMLDocument()
    const hasHTML = withHTML(html)
    const hasHeadOrBody = withHeadOrBody(html)

    if (html !== '') {
      doc.write(
        hasHTML
        ? html
        : hasHeadOrBody
        ? `<html>${html}</html>`
        : `<html><body>${html}</body></html>`
      )
    }

    return (
      hasHTML || hasHeadOrBody
      ? doc.documentElement
      : doc.body
    )
  } catch (e) {
    return createHTMLHolder ('') ()
  }
}

export const getHTMLTypeImpl =
outer =>
inner =>
bodyOuter =>
bodyInner =>
html =>
() =>
  withHTML(html)
  ? outer
  : withBodyOnly(html)
  ? bodyOuter
  : withHeadOrBody(html)
  ? inner
  : bodyInner

export const innerHTML = $elmt => () => $elmt.innerHTML ?? ''
export const outerHTML = $elmt => () => $elmt.outerHTML ?? ''

export const bodyOuterHTML = $elmt => () =>
  $elmt.ownerDocument?.body?.outerHTML ?? ''

export const bodyInnerHTML = $elmt => () =>
  $elmt.ownerDocument?.body?.innerHTML ?? ''

export const setInnerHTML = html => $elmt => () => $elmt.innerHTML = html

export const getDocumentByElement = $elmt => () => $elmt.ownerDocument

export const isSameAs = a => b => a === b

export const isTopParent = node =>
  ['body', 'head', 'html'].includes(node.tagName?.toLowerCase())

export const replaceWithImpl =
  left =>
  right =>
  $replacee =>
  $$node =>
  () =>
{
  try {
    $replacee.replaceWith (...$$node)
    return right ()
  } catch (e) {
    return left (e.message)
  }
}

export const insertBeforeStartImpl =
  left =>
  right =>
  $node =>
  $$insertee =>
  () =>
{
  try {
    if (isTopParent ($node)) {
      $node.prepend (...$$insertee)
    } else {
      $node.before (...$$insertee)
    }
    return right ()
  } catch (e) {
    return left (e.message)
  }
}

export const insertAfterEndImpl =
  left =>
  right =>
  $node =>
  $$insertee =>
  () =>
{
  try {
    if (isTopParent ($node)) {
      $node.append (...$$insertee)
    } else {
      $node.after (...$$insertee)
    }
    return right ()
  } catch (e) {
    return left (e.message)
  }
}

export const removeNodes =
  $$node =>
  () =>
  $$node.forEach($node => $node.remove())

// Prefer `nodeValue` over `textContent` for leaf-type nodes (Text, Comment,
// CDATA): both return the same string but happy-dom's `textContent` getter
// is significantly slower (descends into children even when there are none).
// Elements have `nodeValue === null`, so we fall back to `textContent` for
// them, which performs the recursive concatenation users expect.
export const textContent = $node => () => $node.nodeValue ?? $node.textContent ?? ''
