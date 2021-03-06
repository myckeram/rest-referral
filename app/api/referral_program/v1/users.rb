module ReferralProgram
	module V1
		class Users < ReferralProgram::Base
			resources :users do
				#  get /api/v1/users
				desc 'List all users' do
					summary 'List all users'
					params  ReferralProgram::Entities::User.documentation
					success ReferralProgram::Entities::User
					is_array true
					produces ['application/json']
				end
				get do
					users = User.all
					{ users: ReferralProgram::Entities::User.represent(users).as_json }
				end

				#  post /api/v1/users
				desc 'Create an user' do
					summary 'Create an user'
					params  ReferralProgram::Entities::User.documentation
					success ReferralProgram::Entities::User
					is_array false
					produces ['application/json']
					consumes ['application/json']
				end
				params do
					requires :name, type: String, allow_blank: false
					requires :email, type: String, allow_blank: false, regexp: /.+@.+/
					requires :password, type: String, allow_blank: false
					requires :password_confirmation, type: String, allow_blank: false, same_as: :password
					optional :balance, type: Float
					# optional :referrals, type: Set[Referral]
				end
				post do
					user = User.create!(declared(params))
					{ user: ReferralProgram::Entities::User.represent(user).as_json }
				end

				route_param :id, type: Integer do
					#  get /api/v1/users/:id
					desc 'Get specific user' do
						summary 'Get specific user'
						params  ReferralProgram::Entities::User.documentation
						success ReferralProgram::Entities::User
						is_array false
						produces ['application/json']
					end
					get do
						user = User.find(params[:id])
						{ user: ReferralProgram::Entities::User.represent(user).as_json }
					end

					#  get /api/v1/users/:id/balance
					desc 'Get a specific user\'s balance' do
						summary 'Get user\'s balance'
						is_array false
						produces ['application/json']
					end
					get 'balance' do
						user = User.find(params[:id])
						{ balance: user.balance }
					end

					# put /api/v1/users/:id
					desc 'Update an user' do
						summary 'Update an user'
						params  ReferralProgram::Entities::User.documentation
						success ReferralProgram::Entities::User
						is_array false
						consumes ['application/json']
						produces ['application/json']
					end
					params do
						requires :name, type: String, allow_blank: false
						requires :email, type: String, allow_blank: false, regexp: /.+@.+/
						requires :password, type: String, allow_blank: false
						requires :password_confirmation, type: String, allow_blank: false, same_as: :password
						optional :balance, type: Float
					end
					put do
						user = User.find(params[:id])
						user.update(declared(params))
						{ messages: ['User updated succesfully'] }
					end

					# delete /api/v1/users/:id
					desc 'Delete an user' do
						summary 'Delete an user'
						params  ReferralProgram::Entities::User.documentation
						success ReferralProgram::Entities::User
						is_array false
						produces ['application/json']
					end
					delete do
						User.find(params[:id]).destroy
						{ messages: ['User deleted succesfully'] }
					end

					resources :referrals do
						# get /api/v1/users/:id/referrals
						desc 'List all referrals of an user' do
							summary 'List all referrals'
							params  ReferralProgram::Entities::Referral.documentation
							success ReferralProgram::Entities::Referral
							is_array true
							produces ['application/json']
						end
						get do
							user = User.find(params[:id])
							referrals = user.referrals
							{ referrals: ReferralProgram::Entities::Referral.represent(referrals).as_json }
						end

						# post /api/v1/users/:id/referrals
						desc 'Create a referral' do
							summary 'Create a referral'
							params  ReferralProgram::Entities::Referral.documentation
							success ReferralProgram::Entities::Referral
							is_array false
							produces ['application/json']
						end
						post do
							user = User.find(params[:id])
							referral = user.referrals.create()
							{ referral: ReferralProgram::Entities::Referral.represent(referral).as_json, messages: ['Referral created succesfully']}
						end

						# delete /api/v1/users/:id/referrals/:ref
						desc 'Delete a referral' do
							summary 'Delete a referral'
							params  ReferralProgram::Entities::Referral.documentation
							success ReferralProgram::Entities::Referral
							is_array false
							produces ['application/json']
						end
						delete do
							Referral.find(params[:id]).delete
							{ messages: ['Referral deleted succesfully'] }
						end
					end
				end
			end

			resources :referrals do
				route_param :ref do
					# get /api/v1/referrals/:ref
					desc 'Get specific referral' do
						summary 'Get specific referral'
						params  ReferralProgram::Entities::Referral.documentation
						success ReferralProgram::Entities::Referral
						is_array false
						produces ['application/json']
					end
					get do
						referral = Referral.where(code: params[:ref]).first
						{ referral: ReferralProgram::Entities::Referral.represent(referral).as_json }
					end

					# post /api/v1/referrals/:ref/trigger
					desc 'Trigger a referral' do
						summary 'Trigger a referral'
						params  ReferralProgram::Entities::Referral.documentation
						success ReferralProgram::Entities::Referral
						is_array false
						produces ['application/json']
					end
					params do
						requires :user_id, type: Integer, allow_blank: false
					end
					post 'trigger' do
						created_user = User.find(params[:user_id])
						referral = Referral.find_by(code: params[:ref])

						if (referral.nil?)
							raise ActiveRecord::RecordNotFound.new "Referral not found"
						end

						if (created_user.referee_id.present?)
							raise StandardError.new "This referral was already triggered for this user"
						end

						ActiveRecord::Base.transaction do
							created_user.increment!(:balance, 10)
							created_user.update!(referee_id: referral.user.id)

							referral.increment!(:signups)
							if (referral.signups % 5 == 0)
								referral.user.increment!(:balance, 10)
							end
						end

						{ referral: ReferralProgram::Entities::Referral.represent(referral).as_json, messages: ['Referral triggered succesfully'] }
					end
				end
			end
		end
	end
end