require 'test_helper'

class PasswordResetsTest < ActionDispatch::IntegrationTest
  def setup
    ActionMailer::Base.deliveries.clear
    @user = users(:michael)
  end

  test "password resets" do
    get new_password_reset_path
    assert_template 'password_resets/new'

    # Invalid mail address
    post password_resets_path, params: { password_reset: { email: "" } }
    assert_not flash.empty?
    assert_template 'password_resets/new'

    # Valid mail address
    post password_resets_path, params: { password_reset: { email: @user.email } }
    assert_not_equal @user.reset_digest, @user.reload.reset_digest
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_not flash.empty?
    assert_redirected_to root_url


    # Password reset form test
    user = assigns(:user)

    # Invalid mail address
    get edit_password_reset_path(user.reset_token, email: "")
    assert_redirected_to root_url

    # Invalid user
    user.toggle!(:activated)
    get edit_password_reset_path(user.reset_token, email: user.email)
    assert_redirected_to root_url
    user.toggle!(:activated)

    # Valid mail address and invalid token
    get edit_password_reset_path('wrong token', email: user.email)
    assert_redirected_to root_url

    # Valid mail address and valid token
    get edit_password_reset_path(user.reset_token, email: user.email)
    assert_template 'password_resets/edit'
    assert_select "input[name=email][type=hidden][value=?]", user.email


    # Invalid password
    patch password_reset_path(user.reset_token),
          params: { email: user.email,
                    user: {
                      password: "foobaz",
                      password_confirmation: "foobar" } }
    assert_select 'div#error_explanation'
    # Empty password
    patch password_reset_path(user.reset_token),
          params: { email: user.email,
                    user: {
                      password: "",
                      password_confirmation: "" } }
    assert_select 'div#error_explanation'
    # Valid password
    patch password_reset_path(user.reset_token),
          params: { email: user.email,
                    user: {
                      password: "foobaz",
                      password_confirmation: "foobaz" } }
    assert is_logged_in?
    assert_not flash.empty?
    assert_redirected_to user
  end

  test "expired token" do
    get new_password_reset_path
    post password_resets_path, params: { password_reset: { email: @user.email } }
    @user = assigns(:user)
    @user.update_attribute(:reset_sent_at, 3.hours.ago)
    patch password_reset_path(@user.reset_token),
          params: { email: @user.email,
                    user: {
                      password: "foobaz",
                      password_confirmation: "foobaz" } }
    assert_response :redirect
    follow_redirect!
    assert_match /expired/i, response.body

  end
end
