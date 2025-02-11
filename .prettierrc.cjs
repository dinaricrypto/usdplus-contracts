module.exports = {
  plugins: [require('@trivago/prettier-plugin-sort-imports')],

  printWidth: 120,
  singleQuote: true,
  semi: true,
  trailingComma: 'es5',
  bracketSpacing: false,
  endOfLine: 'lf',
  importOrder: ['<THIRD_PARTY_MODULES>', '^~', '^[./]'],
  importOrderSeparation: true,
  importOrderSortSpecifiers: true,
};
