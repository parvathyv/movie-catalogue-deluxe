require 'sinatra'
require 'pry'
require 'pg'

def db_connection
  begin
  	connection = PG.connect(dbname: 'movies')

    yield(connection)

  ensure
    connection.close
  end
end

def get_actor_name(id)
  query = "SELECT name FROM actors WHERE actors.id = $1;"
  result = db_connection do |conn|
    conn.exec_params(query,[id])
  end  
  result.first['name']
end 

=begin
def get_movie_details(id)

result = db_connection do |conn|
  conn.exec_params('SELECT title, genres.name as genre_name, studios.name as studio_name
  FROM movies join studios on studios.id = movies.studio_id join genres on genres.id = movies.genre_id
  WHERE movies.id = $1',[id])
end  
result.first['title']
end 
=end

def query_actors(filter)

  result = db_connection do |conn|
    
    case filter
    
    when params['page']
      
      offset_multiplier = params['page'].to_i - 1
      filter_query = "ORDER BY actors.name LIMIT 20 OFFSET (20 * #{offset_multiplier})" 
      query = "SELECT actors.id AS actors_id, count(movies.id) AS movie_count,actors.name AS actor_name 
      FROM movies JOIN cast_members ON cast_members.movie_id = movies.id JOIN actors
      on actors.id = cast_members.actor_id GROUP BY actors.id #{filter_query}"
      conn.exec(query)
    
    when params[:actor_name] || params[:id]

      if params[:actor_name]
        filter_to_search = "actors.name" 
      else
        filter_to_search = "actors.id"
      end  
      
      query = "SELECT movies.title AS movie_title,cast_members.character AS character,
               movies.id AS movie_id FROM movies JOIN cast_members ON cast_members.movie_id = movies.id 
               JOIN actors ON cast_members.actor_id = actors.id WHERE #{filter_to_search} = $1;"

      conn.exec_params(query, [filter])

    end

  end 
 
  result.to_a
  
end  


def query_movies(filter = 'all')
   
  temp_query = "SELECT movies.id AS id, movies.title AS title, movies.rating AS rating, genres.name AS genre_name, 
                studios.name AS studio_name, movies.year AS year FROM movies JOIN genres ON genres.id = movies.genre_id 
                JOIN studios ON studios.id = movies.studio_id"


  result = db_connection do |conn|
    case filter
    
    when params['page'] || 'all' || params[:ratingssort] || params[:yearsort]
    
      if params['ratingssort'] == 'Ratings'
        pick_an_order = 'movies.rating'

      else
        if params[:yearsort] == 'Year'
          pick_an_order = 'movies.year'
        else
          pick_an_order = 'movies.title'
        end 
        
      end
      
      filter_query = "order by #{pick_an_order}"  
      
      if params['page']
        offset_multiplier = params['page'].to_i - 1 
        filter_query = "order by #{pick_an_order} LIMIT 20 OFFSET (20 * #{offset_multiplier})"
      end   
   
      query = "#{temp_query} #{filter_query}"
      
      conn.exec(query)
      
    
    when params['query'] 
      filter = "%#{filter}%"
      conn.exec_params("SELECT id, title, rating, year 
        FROM movies WHERE title ILIKE $1 or synopsis ILIKE $1",[filter])

    # params[:id]
    else  
      query = "SELECT actors.id AS actor_id, actors.name as actor_name,
              movies.title AS title,genres.name AS genre_name, studios.name AS studio_name,
              cast_members.character AS character, movies.id AS id
              FROM movies JOIN cast_members ON cast_members.movie_id = movies.id 
              JOIN actors ON cast_members.actor_id = actors.id JOIN genres ON genres.id = movies.genre_id 
              LEFT JOIN studios ON studios.id = movies.studio_id WHERE movies.id = $1;"
      conn.exec_params(query,[filter])
    end

  end 

  result.to_a
  
end  

get '/actors' do

  if !params[:actor_name]
    if !params['page']
      params['page'] = 1
    end  
    @apage_no = params['page'].to_i + 1
    @show = query_actors(params['page'])
    erb :'actors/index'
  else
    @actor_name = params[:actor_name]
    @show = query_actors(params[:actor_name]) if params[:actor_name]
    erb :'actors/show' 
  end

end

get '/actors/:id' do
  if params[:id]
   @actor_name = get_actor_name(params[:id])
   @show = query_actors(params[:id])
  end 
  erb :'actors/show'
end

 
get '/movies' do
  @flag_page = false 
  if params.key?('query')
    @movie = query_movies(params['query'])
  else
    if params.key?(:ratingssort) || params.key?(:yearsort)
      if params.key?(:ratingssort)
        @movie = query_movies(params[:ratingssort])
      else
       @movie = query_movies(params[:yearsort])
      end
    else 
      if !params['page']
        @movie = query_movies
      else  
        @page_no = params['page'].to_i + 1
        @flag_page = true
        @movie = query_movies(params['page'])
      end
    end
  end
  
  erb :'movies/index'
 
end

get '/movies/:id' do
  
  @movie = {} 
  @movie_detail_array = []
  @movie_details = query_movies(params[:id])
  @movie_name = @movie_details.first['title']
  @studio_name = @movie_details.first['studio_name']
  @genre_name = @movie_details.first['genre_name']
  
  @movie_details.each do|row| 
    @movie = {}
    @movie['actor_id'] = row['actor_id']
    @movie['actor_name'] = row['actor_name']
    @movie['character'] = row['character'] 
    @movie_detail_array << @movie
  end

  @movie_details = nil
  @movie = nil
  
  erb :'movies/show'
end