После длительной работы с file_column, acts_as_attachment и attachment_fu, которые друг от друга
решительно ничем не отличаются, были сформулированы претензии к этим плагинам:

1) на каждый тамбнейл создаётся запись в таблице, что лично мне совершенно не нужно;
2) поменять набор тамбнейлов очень сложно, никаких ручек для этого плагин не представляет;
3) невозможно генерировать тамбнейлы на лету;
4) очень сложная логика из-за попыток охватить несколько обработчиков картинок, что само по себе имеет мало смысла:
если есть RMagick, то 99% доступна утилита convert, которая не жрёт память с таким аппетитом;
5) не очень удобно принудительно кропить картинки под нужный размер.

Было принято решение немного переделать плагин attachment_fu (http://svn.techno-weenie.net/projects/plugins/attachment_fu/)
со следующими допущениями:

1) файлы сохраняются только на диск и никуда более;
2) картинки обрабатываются только утилитами identify, convert и mogrify;
3) на одну картинку со всеми её тамбнейлами создаётся только одна запись в БД;
4) картинки можно кропить;
5) тамбнейлы можно перегенерировать;
6) при удалении картинки попросту удаляется вся директория, где лежали все её картинки,
что бы стереть всё то, что может быть туда нагенерировано другими плагинами.

Плюс к этому доработалась такая функциональность, как репликация по scp на другой сервер.
Многим проектам среднего размера, где второй сервер покупается не для скорости, а для надежности,
это будет удобно.

В этом плагине есть метод regenerate_thumbnails!:  Image.regenerate_thumbnails!(:preview)
Если поменялся размер картинки, то таким образом можно перегенерировать все preview

Использование достаточно простое:

Создаётся схема БД наподобие:

	create_table :images do |t|
	  t.string :filename
	  t.string :content_type
	  t.integer :width
	  t.integer :height
	  t.string :type
	end

После чего в классе прописывается:

	class Image < ActiveRecord::Base
	  has_attachment :thumbnails => {:medium => "120x", :large => "800x600", :preview => "100x100"},
	    :croppable_thumbnails => %w(preview)
	  validates_as_attachment
	end

После этого форме аплоада назначается имя uploaded_data и картинки начинают сохраняться.
Вывести картинку можно таким образом:

	<%= image_tag @image.public_filename(:preview) %>


