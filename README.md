# deploys
Simple Ruby/Sinatra app to allow folks to remotely deploy QPixel.

# Install
You don't need to. It's already installed on our web servers :)

# Development
```
git clone git@github.com:codidact/deploys
cd deploys
bundle install
ruby app.rb
```

Doesn't auto-reload so you will need to restart the app when you make changes. Add PEM-encoded public keys to `keys/`
to give the app something to work with.

# License
MIT
