Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Setup wizard
  get "setup", to: "setup#show", as: :setup
  post "setup", to: "setup#create"

  # Village management
  resource :village, only: [ :show, :edit, :update ]

  # Conference management
  resources :conferences do
    get "programs/new", to: "conference_programs#new", as: :new_conference_program
    resources :conference_programs, except: [ :new ], path: "programs"
    resources :conference_roles, only: [ :create, :destroy ]
  end

  # Program management
  resources :programs

  # Defines the root path route ("/")
  root "root#show"
end
