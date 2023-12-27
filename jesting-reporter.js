class JestingReporter {
  constructor(globalConfig, reporterOptions, reporterContext) {
    this._globalConfig = globalConfig;
    this._options = reporterOptions;
    this._context = reporterContext;
  }
	onRunStart(test) {
		console.log('jesting:onRunStart');
	}

  onRunComplete(testContexts, results) {
    console.log('jesting:onRunComplete');
    // console.log('global config: ', this._globalConfig);
    // console.log('options for this reporter from Jest config: ', this._options);
    // console.log('reporter context passed from test scheduler: ', this._context);
  }

  // Optionally, reporters can force Jest to exit with non zero code by returning
  // an `Error` from `getLastError()` method.
  getLastError() {
    if (this._shouldFail) {
      return new Error('Custom error reported!');
    }
  }
}

module.exports = JestingReporter;

