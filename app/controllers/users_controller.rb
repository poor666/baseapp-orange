class UsersController < ApplicationController
  skip_before_filter :verify_authenticity_token, :only => :create
  
  before_filter :find_user, 
    :only => [:profile, 
              :destroy, 
              :edit_password,   :update_password, 
              :edit_email,      :update_email ]
  
  layout 'login'
  
  # render new.rhtml
  def new
    @user = User.new
  end

  def troubleshooting
    # Render troubleshooting.html.erb
    render :layout => 'login'
  end

  def clueless
    # These users are beyond our automated help...
    render :layout => 'login'
  end

  def forgot_login    
    if request.put?
      begin
        @user = User.find_by_email(params[:email], :conditions => ['NOT state = ?', 'deleted'])
        
        if ! @user.not_using_openid?
          flash[:notice] = "Lamentamos mas não podemos ajudar, está a usar OpenID!"
          redirect_to :back
        end
      rescue
        @user = nil
      end
      
      if @user.nil?
        flash.now[:error] = 'Não encontramos uma conta com esse e-mail.'
      else
        UserMailer.deliver_forgot_login(@user)
      end
    else
      # Render forgot_login.html.erb
    end
    
    render :layout => 'login'
  end

  def forgot_password    
    if request.put?
      @user = User.find_by_login_or_email(params[:email_or_login])

      if @user.nil?
        flash.now[:error] = 'Não encontramos uma conta com esse e-mail ou login.'
      else
        if ! @user.not_using_openid?
          flash[:notice] = "Lamentamos mas não podemos ajudar, está a usar OpenID!"
          redirect_to :back
        else
          @user.forgot_password if @user.active?
        end
      end
    else
      # Render forgot_password.html.erb
    end
    
    render :layout => 'login'
  end
  
  def reset_password    
    begin
      @user = User.find_by_password_reset_code(params[:password_reset_code])
    rescue
      @user = nil
    end
    
    unless @user.nil? || !@user.active?
      @user.reset_password!
    end
    
    render :layout => 'login'
  end

  def create
    logout_keeping_session!
    if using_open_id?
      authenticate_with_open_id(params[:open_id_url], :return_to => open_id_create_url,
        :required => [:nickname, :email]) do |result, identity_url, registration|
        if result.successful?
          create_new_user(:identity_url => identity_url, :login => identity_url, :email => registration['email'])
        else
          failed_creation(result.message || "Oops, algo correu mal.")
        end
      end
    else
      create_new_user(params[:user])
    end
  end

  def activate
    logout_keeping_session!
    user = User.find_by_activation_code(params[:activation_code]) unless params[:activation_code].blank?
    case
    when (!params[:activation_code].blank?) && user && !user.active?
      user.activate!
      flash[:notice] = "Registo completo! Faça login para continuar."
      redirect_to login_path
    when params[:activation_code].blank?
      flash[:error] = "Falta o código de activação. Por favor siga o URL presente no e-mail."
      redirect_back_or_default(root_path)
    else 
      flash[:error]  = "Não conseguimos encontrar um utilizador com esse código. -- Talvez já esteja activado -- experimente fazer login."
      redirect_back_or_default(root_path)
    end
  end
  
  def edit_password
    if ! @user.not_using_openid?
      flash[:notice] = "Não pode alterar o seu endereço de e-mail. Está a usar OpenId!"
      redirect_to :back
    end
    
    # render edit_password.html.erb
  end
  
  def update_password    
    if ! @user.not_using_openid?
      flash[:notice] = "Não pode alterar o seu endereço de e-mail. Está a usar OpenId!"
      redirect_to :back
    end
    
    if current_user == @user
      current_password, new_password, new_password_confirmation = params[:current_password], params[:new_password], params[:new_password_confirmation]
      
      if @user.encrypt(current_password) == @user.crypted_password
        if new_password == new_password_confirmation
          if new_password.blank? || new_password_confirmation.blank?
            flash[:error] = "Não pode ter uma password vazia."
            redirect_to edit_password_user_url(@user)
          else
            @user.password = new_password
            @user.password_confirmation = new_password_confirmation
            @user.save
            flash[:notice] = "A password foi actualizada."
            redirect_to profile_url(@user)
          end
        else
          flash[:error] = "A password nova e a confirmação não coincide."
          redirect_to edit_password_user_url(@user)
        end
      else
        flash[:error] = "A sua password actual não está correcta. A password não foi alterada."
        redirect_to edit_password_user_url(@user)
      end
    else
      flash[:error] = "Não pode alterar a password de outro utilizador!"
      redirect_to edit_password_user_url(@user)
    end
  end
  
  def edit_email
    if ! @user.not_using_openid?
      flash[:notice] = "Não pode alterar o seu endereço de e-mail. Está a usar OpenId!"
      redirect_to :back
    end
    
    # render edit_email.html.erb
  end
  
  def update_email
    if ! @user.not_using_openid?
      flash[:notice] = "Não pode alterar o seu endereço de e-mail. Está a usar OpenId!"
      redirect_to :back
    end
    
    if current_user == @user
      if @user.update_attributes(:email => params[:email])
        flash[:notice] = "A conta de e-mail foi alterada."
        redirect_to profile_url(@user)
      else
        flash[:error] = "Ouve um problema ao alterar a conta de e-mail. Tente mais tarde, obrigado."
        redirect_to edit_email_user_url(@user)
      end
    else
      flash[:error] = "Não pode alterar a conta de e-mail de outro utilizador."
      redirect_to edit_email_user_url(@user)
    end
  end  
  
  # DELETE /users/1
  # DELETE /users/1.xml
  def destroy
    current_user.delete!
    
    logout_killing_session!
    
    flash[:notice] = "A sua conta foi removida."
    redirect_back_or_default(root_path)
  end  
  
  protected

  def find_user
    @user = User.find(params[:id])
  end

  def create_new_user(attributes)
    @user = User.new(attributes)
    if @user && @user.valid?
      if @user.not_using_openid?
        @user.register!
      else
        @user.register_openid!
      end
    end
    
    if @user.errors.empty?
      successful_creation(@user)
    else
      failed_creation
    end
  end
  
  def successful_creation(user)
    redirect_back_or_default(root_path)
    flash[:notice] = "Obrigado por registar!"
    flash[:notice] << " Foi enviado um e-mail com o código de activação da conta." if @user.not_using_openid?
    flash[:notice] << " Pode entrar com o seu login OpenID." if ! @user.not_using_openid?
  end
  
  def failed_creation(message = 'Lamentamos, ouve um erro ao criar a sua conta')
    flash[:error] = message
    # @user = User.new
    render :action => :new
  end
end
