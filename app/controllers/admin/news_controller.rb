class Admin::NewsController < ApplicationController
  require_role :admin
  layout 'admin'

  def index
     @news = News.paginate :all, :page => params[:page]

     respond_to do |format|
       format.html # index.html.erb
       format.xml  { render :xml => @news }
     end
   end

   def show
     @news = News.find(params[:id])

     respond_to do |format|
       format.html # show.html.erb
       format.xml  { render :xml => @news }
     end
   end

   def new
     @news = News.new
     @news.language = "pt"
     @news.state ="active"

     respond_to do |format|
       format.html # new.html.erb
       format.xml  { render :xml => @news }
     end
   end

   def edit
     @news = News.find(params[:id])
   end

   def create
     @news = News.new(params[:news])

     respond_to do |format|
       if @news.save
         flash[:notice] = 'Página foi criada com sucesso.'
         format.html {  redirect_to(admin_news_url) }
         format.xml  { render :xml => @news, :status => :created, :location => @news }
       else
         format.html { render :action => "new" }
         format.xml  { render :xml => @news.errors, :status => :unprocessable_entity }
       end
     end
   end

   def update
     @news = News.find(params[:id])

     respond_to do |format|
       if @news.update_attributes(params[:news])
         flash[:notice] = 'Notícia foi gravada com sucesso.'
         format.html {  redirect_to(admin_news_url) }
         format.xml  { head :ok }
       else
         format.html { render :action => "edit" }
         format.xml  { render :xml => @news.errors, :status => :unprocessable_entity }
       end
     end
   end

   def destroy
     @news = News.find(params[:id])
     @news.destroy

     respond_to do |format|
       format.html { redirect_to(admin_news_url) }
       format.xml  { head :ok }
     end
   end
end
