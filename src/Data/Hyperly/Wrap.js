const VALID_ELMT_NAME = /^[a-z]([a-z0-9\._\-]*[a-z0-9])?$/i
const POSSIBLE_HTML_PATTERN = /^<([a-z]([a-z0-9._-]*[a-z0-9])?)(\s+[a-z][a-z0-9._-]*="[^"]*")*\s*(\/?>|>[^<]*<\/\1>)$/i

export const createWrapperElmtImpl = left => right => name => doc => () => {
  try {
    if (VALID_ELMT_NAME.test(name)) {
      return right (doc.createElement(name))
    } else if (POSSIBLE_HTML_PATTERN.test(name)) {
      const $div = doc.createElement('div')
      $div.innerHTML = name
      return right ($div.firstElementChild)
    } else {
      return left (`Failed to create wrappable element: (\`${name}\`) is not a valid element name nor a possible HTML string.`)
    }
  } catch (e) {
    return left (e.message)
  }
}
