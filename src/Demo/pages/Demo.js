
export const attrs = n => () =>
  Array.from(n.attributes)
  .reduce(
    (acc, { name, value }) => acc + ` ${name}="${value}"`,
    '',
  )
