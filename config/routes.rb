Rails.application.routes.draw do

  namespace :foreman_xen do
    match 'snapshots/:id', :to => 'snapshots#show', :via => 'get'
    match 'snapshots/:id/revert/:ref', :to => 'snapshots#revert', :via => 'get'
    match 'snapshots/:id/new', :to => 'snapshots#new', :via => 'get'
    match 'snapshots/:id/delete/:ref', :to => 'snapshots#destroy', :via => 'get'

    match 'snapshots/:id/create', :to => 'snapshots#create', :via => 'post'
  end

end
