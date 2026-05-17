Rails.application.routes.draw do
  root "issues#index"
  resources :issues, only: :index do
    collection do
      get :random
    end
  end
  resources :projects, only: %i[index show]
end
