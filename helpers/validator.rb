module Validator
    EMAIL_PATTERN = /\A[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\z/

# Username + Email checks (shared by registration and profile updates)
def self.validate_account(username, email)
    return [false, "Username must be at least 3 characters."] if username.nil? || username.strip.length < 3
    return [false, "Invalid email format (e.g., user@email.com)."] if email.nil? || !(email =~ EMAIL_PATTERN)
    [true, "Valid"]
end
#user Input Validation
def self.validate_user(username, email, password)
    return [false, "Username must be at least 3 characters."] if username.nil? || username.strip.length < 3
    return [false, "Invalid email format (e.g., user@email.com)."] if email.nil? || !(email =~ EMAIL_PATTERN)
    return [false, "Password must be at least 6 characters."] if password.nil? || password.length < 6
    [true, "Valid"]
end

# User Input Validation (registration)
def self.validate_user(username, email, password)
    valid, msg = validate_account(username, email)
    return [valid, msg] unless valid
    return [false, "Password must be at least 6 characters."] if password.nil? || password.length < 6
    [true, "Valid"]
end

# Profile Update Validation (no password on the profile form)
def self.validate_profile(username, email, street, city, state, zip_code)
    valid, msg = validate_account(username, email)
    return [valid, msg] unless valid
    validate_address(street, city, state, zip_code)
end

#address Input Validation
def self.validate_address(street, city, state, zip_code)
    if [street, city, state, zip_code].any? { |field| field.nil? || field.strip.empty? }
        return [false, "All address fields (Street, City, State, Zip) are required."]
    end
    [true, "Valid"]
end

#post Input Validation
def self.validate_post(title, content)
    return [false, "Post title is required."] if title.nil? || title.strip.empty?
    return [false, "Post content is required."] if content.nil? || content.strip.empty?
    [true, "Valid"]
end

#attachment Input Validation
def self.validate_attachment(file_name, file_type, file_size, current_attachment_count)
    if current_attachment_count >= 5
        return [false, "Maximum limit of 5 attachments per post reached."]
    end
    return [false, "File name is required."] if file_name.nil? || file_name.strip.empty?
    return [false, "File type is required."] if file_type.nil? || file_type.strip.empty?
    return [false, "File size must be greater than 0 KB."] if file_size.nil? || file_size.to_i <= 0
    [true, "Valid"]
end
end
