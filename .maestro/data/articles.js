// Test data: long-lived Wikipedia articles used by tests.
// Values come from live Wikipedia; pick stable articles and avoid asserting
// on result ranking. `title` and `description` are regexes (escape parentheses).
output.articles = {
  apollo11: {
    query: 'Apollo 11',
    title: 'Apollo 11',
    description: 'First crewed Moon landing \\(1969\\)',
  },
};
