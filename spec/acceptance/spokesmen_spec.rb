require File.dirname(__FILE__) + '/acceptance_helper'

feature "Spokesmen", %q{
  In order to create a chain of trust
  As a user
  I want to choose my spokesman
} do
  
  background do
    @user = create_user(:login => "123456789A")
  end
  
  scenario "View Users" do
    zapatero = create_user :login => "Jose Luis"
    rajoy = create_user :login => "Mariano"
    
    visit "/"
    click_link "Usuari@s"

    page.should have_css(".user .name a", :text => "Jose Luis", :href => user_path(zapatero))
    page.should have_css(".user .name a", :text => "Mariano", :href => user_path(rajoy))
  end
    
  scenario "Choose spokesman" do
    fan_de_punset = create_user :login => "Fan de Punset"
    login_as @user
    
    visit users_path
    click_link "Fan de Punset"
    click_button "Elegir a Fan de Punset como mi portavoz"
    
    page.should have_content("Has elegido a tu portavoz.")
    @user.reload
    @user.spokesman.should == fan_de_punset
  end
  
  scenario "Discharge spokesman" do
    zapatero = create_user :login => "Zapatero"
    @user.spokesman = zapatero
    @user.save!
    
    login_as @user
    
    visit users_path
    click_link "Zapatero"
    click_button "Destituir a Zapatero de ser mi portavoz"

    page.should have_content("Has destituido a tu portavoz.")

    @user.reload
    @user.spokesman.should == nil
  end
  
  scenario "Display the correct button in a spokeman's page" do
    rajoy = create_user :login => "Rajoy"
    zapatero = create_user :login => "Zapatero"
    
    @user.spokesman = zapatero
    @user.save!
    
    login_as @user

    visit user_path(zapatero)
    page.should have_css("#discharge_spokesman_button")
    
    visit user_path(rajoy)
    page.should have_css("#choose_spokesman_button")
    page.should_not have_css("#discharge_spokesman_button")
  end
  
  scenario "Don't allow to choose spokesman unless user is logged in" do
    fan_de_punset = create_user :login => "Fan de Punset"
    
    visit users_path
    click_link "Fan de Punset"
    click_button "Elegir a Fan de Punset como mi portavoz"

    page.should have_content("Autenticación requerida")
    page.should_not have_content("Has elegido a tu portavoz.")
    
    fill_in "user_session_login", :with => @user.login
    fill_in "user_session_password", :with => "secret"
    click_button "user_session_submit"
    
    page.should have_content("Has elegido a tu portavoz.")
  end
  
  scenario "Don't allow to choose myself as a my own spokesman" do
    login_as @user
    visit user_path(@user)
    page.should_not have_css("#choose_spokesman_button")
  end
  
  scenario "View proposals voted by the user" do
    [["Ley Sinde",           "no",         "En contra",  "voted_against"], 
     ["Wifi gratis",         "si",         "A favor",    "voted_in_favor"], 
     ["Ley que no entiendo", "abstencion", "Abstención", "voted_abstention"]].each do |title, vote, humanize_vote_text, css_image|
 
      proposal = create_proposal :title => title
      create_vote :user => @user, :proposal => proposal, :value => vote
      
      visit user_path(@user)
      
      page.should have_css(".proposal")
      within(:css, "#proposal_#{proposal.id}") do
        page.should have_css(".title", :text => title)
        page.should have_css(".#{css_image}", :text => humanize_vote_text)
      end
    end
  end
  
  scenario "Update vote count when a spokesman is chosen" do
    free_wifi = create_proposal :title => "Wifi Gratis en toda España"
    punset = create_user :login => "Punset" 
    create_vote :proposal => free_wifi, :user => punset, :value => "si"
    
    visit user_path(punset)
    
    within(:css, "#proposal_#{free_wifi.id}") do
      page.should have_css(".in_favor span.vote_count", :text => "1 votos")
    end
    
    login_as @user
    visit user_path(punset)
    click_button "Elegir a Punset como mi portavoz"
    
    within(:css, "#proposal_#{free_wifi.id}") do
      page.should have_css(".in_favor span.vote_count", :text => "2 votos")
      page.should have_css(".in_favor span.vote_percentage", :text => "100%")
    end
  end
  
  scenario "Update vote count when a spokesman is discharged" do
    zapatero = create_user :login => "Zapatero" 
    @user.spokesman = zapatero
    @user.save!
    
    economia_sostenible = create_proposal :title => "Ley de Economia sostenible"
    create_vote :proposal => economia_sostenible, :user => zapatero, :value => "si"

    economia_sostenible.count_delegated_votes!

    visit user_path(zapatero)

    within(:css, "#proposal_#{economia_sostenible.id}") do
      page.should have_css(".in_favor span.vote_count", :text => "2 votos")
    end
    
    login_as @user
    visit user_path(zapatero)
    click_button "Destituir a Zapatero de ser mi portavoz"

    within(:css, "#proposal_#{economia_sostenible.id}") do
      page.should have_css(".in_favor span.vote_count", :text => "1 votos")
      page.should have_css(".in_favor span.vote_percentage", :text => "100%")
    end
  end
    
  scenario "Update vote percentages when a spokesman is chosen/discharged" do    
    free_wifi = create_proposal :title => "Wifi Gratis en toda España"
    punset = create_user :login => "Punset" 
    telefonica = create_user :login => "Telefonica" 

    create_vote :proposal => free_wifi, :user => punset, :value => "si"
    create_vote :proposal => free_wifi, :user => telefonica, :value => "no"
    
    login_as @user
    visit user_path(punset)
    
    percentages_should_be(free_wifi, :in_favor => 50, :against => 50, :abstention => 0)
    
    click_button "Elegir a Punset como mi portavoz"
    percentages_should_be(free_wifi, :in_favor => 67, :against => 33, :abstention => 0)
    
    click_button "Destituir a Punset de ser mi portavoz"
    percentages_should_be(free_wifi, :in_favor => 50, :against => 50, :abstention => 0)
  end

end