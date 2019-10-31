# Usage

## Build the image
`docker build -t esle-box .`

## Run the image in the background

`docker run -d -p 5432:5432 --name esle-live -e POSTGRES_PASSWORD=else esle-box`

## Connect to the database
`psql -h localhost -p 5432 -U postgres -W`
