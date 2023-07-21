export const createNodesFromHTMLImpl =
  left =>
  right =>
  html =>
  doc =>
  () =>
{
  try {
    const $div = doc.createElement('div')
    $div.innerHTML = html
    return right (Array.from($div.childNodes))
  } catch (e) {
    return left (e.message)
  }
}
