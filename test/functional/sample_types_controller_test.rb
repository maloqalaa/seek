require 'test_helper'

class SampleTypesControllerTest < ActionController::TestCase

  include AuthenticatedTestHelper

  setup do
    @person = Factory(:person)
    @project = @person.projects.first
    refute_nil @project
    login_as(@person)
    @sample_type = Factory(:simple_sample_type)
    @string_type = Factory(:string_sample_attribute_type)
    @int_type = Factory(:integer_sample_attribute_type)
  end

  test 'should get index' do
    get :index
    assert_response :success
    refute_nil assigns(:sample_types)
  end

  test 'should get new' do
    get :new
    assert_response :success
  end

  test 'should create sample_type' do
    @person.projects.first

    assert_difference('SampleType.count') do
      post :create, sample_type: { title: 'Hello!',
                                   project_ids:[@project.id],
                                   sample_attributes_attributes: {
                                     '0' => {
                                       pos: '1', title: 'a string', required: '1', is_title: '1',
                                       sample_attribute_type_id: @string_type.id, _destroy: '0' },
                                     '1' => {
                                       pos: '2', title: 'a number', required: '1',
                                       sample_attribute_type_id: @int_type.id, _destroy: '0'
                                     }
                                   }
      }
    end

    assert_redirected_to sample_type_path(assigns(:sample_type))
    assert_equal 2, assigns(:sample_type).sample_attributes.size
    assert_equal 'a string', assigns(:sample_type).sample_attributes.title_attributes.first.title
    assert_equal [@project],assigns(:sample_type).projects
    refute assigns(:sample_type).uploaded_template?
    assert SampleTemplateGeneratorJob.new(assigns(:sample_type)).exists?
  end

  test 'should create with linked sample type' do
    linked_sample_type = Factory(:sample_sample_attribute_type)
    assert_difference('SampleType.count') do
      post :create, sample_type: { title: 'Hello!',
                                   project_ids:[@project.id],
                                   sample_attributes_attributes: {
                                       '0' => {
                                           pos: '1', title: 'a string', required: '1', is_title: '1',
                                           sample_attribute_type_id: @string_type.id, _destroy: '0' },
                                       '1' => {
                                           pos: '2', title: 'a sample', required: '1',
                                           sample_attribute_type_id: linked_sample_type.id, linked_sample_type_id:@sample_type.id, _destroy: '0'
                                       }
                                   }
      }
    end
    refute_nil sample_type=assigns(:sample_type)
    assert_redirected_to sample_type_path(sample_type)
    assert_equal 2, sample_type.sample_attributes.size
    assert_equal 'a string', sample_type.sample_attributes.title_attributes.first.title
    assert_equal 'a sample', sample_type.sample_attributes.last.title
    assert sample_type.sample_attributes.last.sample_attribute_type.seek_sample?
  end

  test 'should show sample_type' do
    get :show, id: @sample_type
    assert_response :success
  end

  test 'should get edit if no samples' do
    get :edit, id: @sample_type
    assert_response :success
  end

  test 'should not get edit if has existing samples' do
    FactoryGirl.create_list(:sample, 3, sample_type: @sample_type)
    get :edit, id: @sample_type
    assert_response :redirect
    assert_equal 'Cannot edit this sample type - There are 3 samples using it.', flash[:error]
  end

  test 'should update sample_type' do
    sample_type = Factory(:patient_sample_type)

    sample_attributes_fields = sample_type.sample_attributes.map do |attribute|
      { pos: attribute.pos, title: attribute.title,
        required: (attribute.required ? '1' : '0'),
        sample_attribute_type_id: attribute.sample_attribute_type_id,
        _destroy: '0',
        id: attribute.id
      }
    end

    sample_attributes_fields[0][:is_title] = '0'
    sample_attributes_fields[1][:title] = 'hello'
    sample_attributes_fields[1][:is_title] = '1'
    sample_attributes_fields[2][:_destroy] = '1'
    sample_attributes_fields = Hash[sample_attributes_fields.each_with_index.map { |f, i| [i, f] }]

    assert_difference('SampleAttribute.count', -1) do
      put :update, id: sample_type, sample_type: { title: 'Hello!',
                                                   sample_attributes_attributes: sample_attributes_fields
      }
    end
    assert_redirected_to sample_type_path(assigns(:sample_type))

    assert_equal sample_attributes_fields.keys.size - 1, assigns(:sample_type).sample_attributes.size
    assert_includes assigns(:sample_type).sample_attributes.map(&:title), 'hello'
    refute assigns(:sample_type).sample_attributes[0].is_title?
    assert assigns(:sample_type).sample_attributes[1].is_title?
    assert SampleTemplateGeneratorJob.new(assigns(:sample_type)).exists?
  end

  test 'should not update sample_type if has existing samples' do
    FactoryGirl.create_list(:sample, 3, sample_type: @sample_type)
    get :update, id: @sample_type, sample_attributes_attributes: {
      pos: 1,
      title: 'fish',
      required: '1',
      _destroy: '0',
      id: @sample_type.sample_attributes.first.id
    }
    assert_response :redirect
    assert_equal 'Cannot update this sample type - There are 3 samples using it.', flash[:error]
  end

  test 'should destroy sample_type' do
    assert_difference('SampleType.count', -1) do
      delete :destroy, id: @sample_type
    end

    assert_redirected_to sample_types_path
  end

  test 'should not destroy sample_type if has existing samples' do
    FactoryGirl.create_list(:sample, 3, sample_type: @sample_type)

    assert_no_difference('SampleType.count') do
      delete :destroy, id: @sample_type
    end

    assert_response :redirect
    assert_equal 'Cannot destroy this sample type - There are 3 samples using it.', flash[:error]
  end

  test 'create from template' do
    blob = { data: template_for_upload }

    assert_difference('SampleType.count', 1) do
      assert_difference('ContentBlob.count', 1) do
        post :create_from_template, sample_type: { title: 'Hello!',project_ids:[@project.id] }, content_blobs: [blob]
      end
    end

    assert_redirected_to edit_sample_type_path(assigns(:sample_type))
    assert_empty assigns(:sample_type).errors
    assert assigns(:sample_type).uploaded_template?
  end

  test 'create from template with some blank columns' do
    blob = { data: missing_columns_template_for_upload }

    assert_difference('SampleType.count', 1) do
      assert_difference('ContentBlob.count', 1) do
        post :create_from_template, sample_type: { title: 'Hello!',project_ids:[@project.id] }, content_blobs: [blob]
      end
    end

    assert_redirected_to edit_sample_type_path(assigns(:sample_type))
    assert_empty assigns(:sample_type).errors
  end

  test "don't create from bad template" do
    blob = { data: bad_template_for_upload }

    assert_no_difference('SampleType.count') do
      assert_no_difference('ContentBlob.count') do
        post :create_from_template, sample_type: { title: 'Hello!' }, content_blobs: [blob]
      end
    end

    assert_template :new
    assert_not_empty assigns(:sample_type).errors
  end

  test 'should show link to sample type for linked attribute' do
    linked_type = Factory(:linked_sample_type)
    linked_attribute = linked_type.sample_attributes.last

    assert linked_attribute.sample_attribute_type.seek_sample?

    sample_type_linked_to = linked_attribute.linked_sample_type
    refute_nil sample_type_linked_to

    get :show,id:linked_type.id

    record_body
    assert_select 'li',:text=>/patient \(#{linked_attribute.sample_attribute_type.title}/i do
      assert_select 'a[href=?]',sample_type_path(sample_type_linked_to),text:sample_type_linked_to.title
    end

  end

  test 'cannot access when disabled' do
    person = Factory(:person)
    sample_type = Factory(:simple_sample_type)
    login_as(person.user)
    with_config_value :samples_enabled,false do

      get :show, id: sample_type.id
      assert_redirected_to :root
      refute_nil flash[:error]

      flash[:error]=nil

      get :index
      assert_redirected_to :root
      refute_nil flash[:error]

      flash[:error]=nil

      get :new
      assert_redirected_to :root
      refute_nil flash[:error]

    end

  end

  private

  def template_for_upload
    ActionDispatch::Http::UploadedFile.new(filename: 'sample-type-example.xlsx',
                                           content_type: 'application/excel',
                                           tempfile: fixture_file_upload('files/sample-type-example.xlsx'))
  end

  def bad_template_for_upload
    ActionDispatch::Http::UploadedFile.new(filename: 'small-test-spreadsheet.xls',
                                           content_type: 'application/excel',
                                           tempfile: fixture_file_upload('files/small-test-spreadsheet.xls'))
  end

  def missing_columns_template_for_upload
    ActionDispatch::Http::UploadedFile.new(filename: 'samples-data-missing-columns.xls',
                                           content_type: 'application/excel',
                                           tempfile: fixture_file_upload('files/samples-data-missing-columns.xls'))
  end
end
