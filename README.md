# Retro

Retro is a tool to create retrospectives (SCRUM) and hold them with your team.

## Installation

Use [docker](https://docs.docker.com/) and [docker-compose](https://docs.docker.com/compose/) to install and run retro.

First clone the project and navigate in the project directory. Then simply run docker-compose.
```bash
docker-compose up
```
This will download all required images and build the project.
## Usage
After the project is build go to [localhost](http://localhost:80)

## Development
#### Requirements:
Install mongodb on your machine:
```bash
brew update
brew install mongodb-community
```
Install redis on your machine:
```bash
brew update
brew install redis
```
#### Start development:
After installing all requirements the services need to be started:
```bash
brew services start redis
brew services start mongodb-community
```
To stop the services run:
```bash
brew services stop redis
brew services stop mongodb-community
```
Then cd into retro-board and run:
```bash
npm run dev:server
```
This starts the server in watch mode and will trigger a restart whenever something changes.
#### Start development with elm:
To run webpack in watch mode and build all elm-applications in retroboard, open another terminal and run:
```bash
npm run dev:frontend
```
This will build the current state of board, board-admin and board-builder and watches the files for changes. There is no hotreload so you have to reload manualy.
## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License
[GPLv3](https://choosealicense.com/licenses/gpl-3.0/)
