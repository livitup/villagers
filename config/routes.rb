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

  # API endpoints for dynamic form fields
  get "states", to: "states#index", as: :states

  # Village management
  resource :village, only: [ :show, :edit, :update ]

  # Conference management
  resources :conferences do
    member do
      post :archive
      post :unarchive
    end
    collection do
      post :bulk_archive
    end
    get "dashboard", to: "conference_dashboard#show", as: :dashboard
    get "calendar_export", to: "calendar_exports#show", as: :calendar_export
    get "programs/new", to: "conference_programs#new", as: :new_conference_program
    resources :conference_programs, except: [ :new ], path: "programs"
    resources :custom_programs, only: [ :new, :create, :edit, :update, :destroy ]
    resources :conference_roles, only: [ :create, :destroy ]
    get "calendar", to: "calendar#show", as: :calendar
    get "schedule", to: "schedule#show", as: :schedule
    get "leaderboard", to: "leaderboard#conference", as: :leaderboard
    resources :volunteer_signups, only: [ :index, :create, :destroy ]
    resources :timeslots, only: [ :update ] do
      member do
        post :add_volunteer
        delete :remove_volunteer
      end
    end
    resources :reports, controller: "conference_reports", only: [ :index ] do
      collection do
        get :shift_assignments
        get :unmanned_shifts
      end
    end
    resources :conference_qualifications, path: "qualifications"
    resources :conference_user_qualifications, only: [ :create, :destroy ]
    resources :qualification_removals, only: [ :index, :create, :destroy ]
  end

  # Program management
  resources :programs do
    member do
      get :affected_conferences
      post :bulk_update_capacity
    end
    resources :program_qualifications, only: [ :create, :destroy ]
  end

  # Qualification management
  resources :qualifications
  resources :managed_users, controller: "users", path: "manage/users" do
    resources :user_qualifications, only: [ :create, :destroy ]
  end

  # Leaderboard
  resources :leaderboard, only: [ :index ]

  # Volunteer history
  resources :volunteer_history, only: [ :index, :show ]

  # Defines the root path route ("/")
  root "root#show"
end
