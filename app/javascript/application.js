// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
// Eagerly import TomSelect so the module is already resolved when the
// select controller connects, avoiding a flash of unstyled native selects.
import "tom-select"

