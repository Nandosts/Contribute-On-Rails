Rails.application.routes.draw do
  root "issues#index"
  resources :issues, only: :index
  resources :projects, only: %i[index show]
end
