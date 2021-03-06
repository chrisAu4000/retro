var path = require('path');
const outputDir = path.resolve(__dirname, 'server/public/board.js');
module.exports = {
	mode: process.env.DEVELOPMENT ? 'development' : 'production',
	entry: './elm-apps/board/index.js',
	output: {
		filename: 'board.js',
		path: path.resolve(__dirname, 'server/public'),
	},
	// If your entry-point is at "src/index.js" and
	// your output is in "/dist", you can ommit
	// these parts of the config
	module: {
		rules: [
			{
				test: /\.elm$/,
				exclude: [/elm-stuff/, /node_modules/],
				// This is what you need in your own work
				loader: "elm-webpack-loader",
				options: {
					output: outputDir,
					cwd: path.resolve(__dirname, 'elm-apps/board'),
					pathToElm: path.resolve(__dirname, 'node_modules/.bin/elm'),
					verbose: true,
					debug: process.env.DEVELOPMENT || false,
				}
			}
		],
		noParse: [/.elm$/]
	},
	watch: process.env.DEVELOPMENT === 'true',
	watchOptions: {
		ignored: ['**/node_modules'],
	}
};