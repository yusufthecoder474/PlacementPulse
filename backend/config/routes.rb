Rails.application.routes.draw do
  # Health check (Rails default): 200 when the app boots, 500 otherwise.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    post "sessions", to: "sessions#create"
    delete "sessions", to: "sessions#destroy"
    get "me", to: "me#show"
    patch "profile", to: "profiles#update"

    # Declared before resources so /notices/parse is not captured as :id.
    post "notices/parse", to: "notices#parse"

    resources :notices, only: %i[index show create update] do
      member do
        post :publish
        get :eligibility
      end
      post "registration", to: "registrations#create"
      delete "registration", to: "registrations#destroy"
    end
  end
end
