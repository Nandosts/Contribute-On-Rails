Rails.application.routes.draw do
  root "issues#index"

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :issues, only: :index do
    collection do
      get :random
    end
  end
  resources :projects, only: %i[index show]

  namespace :api do
    resources :syncs, only: :create
  end
end
