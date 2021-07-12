var path = require('path');
const outputDir = path.resolve(__dirname, 'public/board.js');
module.exports = {
	mode: process.env.DEVELOPMENT ? 'development' : 'production',
	entry: './elm-apps/board-admin/index.js',
	output: {
		filename: 'board-admin.js',
		path: path.resolve(__dirname, 'public'),
	},
	module: {
		rules: [
			{
				test: /\.elm$/,
				exclude: [/elm-stuff/, /node_modules/],
				// This is what you need in your own work
				loader: "elm-webpack-loader",
				options: {
					output: outputDir,
					cwd: path.resolve(__dirname, 'elm-apps/board-admin'),
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