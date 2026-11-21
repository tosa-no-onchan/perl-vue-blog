<script setup>
import { ref, onMounted } from 'vue'

const posts = ref([])
const currentPage = ref(1)
const totalPages = ref(1)

const title = ref('')
const content = ref('')
const loading = ref(false)
const error = ref('')

// 検索用の状態
const searchInput = ref('')
const searchQuery = ref('')

// 編集用の状態
const editingId = ref(null)
const editTitle = ref('')
const editContent = ref('')

const use_cgi = 1
const API_URL = 'http://localhost:3000/api/posts'

// 今ページを開いているホスト（例: 192.168.1.170 や localhost）を基準にする
// C++ サーバーが port 80 で動いている前提ならオリジンはそのまま使える
const buildApiUrl = (queryObj = {}) => {
  //const base = `${window.location.protocol}//${window.location.host}/cgi-bin/api/posts.cgi`
  const base = 'http://192.168.1.170/cgi-bin/api/posts.cgi'
  const params = new URLSearchParams()
  for (const [key, val] of Object.entries(queryObj)) {
    if (val !== undefined && val !== null && String(val) !== '') {
      params.set(key, String(val))
    }
  }
  const qs = params.toString()
  return qs ? `${base}?${qs}` : base
}

// ページを指定して記事一覧を取得
const fetchPosts = async (page = 1, q = searchQuery.value) => {
  try {
    if (use_cgi == 1){
      const url = buildApiUrl({ page, q })
      const res = await fetch(url)
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'データの取得に失敗しました')

      posts.value = data.posts || []
      currentPage.value = data.current_page || 1
      totalPages.value = data.total_pages || 1
    }
    else{
      const params = new URLSearchParams({ page: String(page) })
      if (q) params.set('q', q)

      const res = await fetch(`${API_URL}?${params.toString()}`)
      const data = await res.json()
      posts.value = data.posts
      currentPage.value = data.current_page
      totalPages.value = data.total_pages
    }
  } catch (e) {
    error.value = 'データの取得に失敗しました'
  }
}

// keywards 検索
const handleSearch = async () => {
  searchQuery.value = searchInput.value.trim()
  await fetchPosts(1, searchQuery.value)
}

const clearSearch = async () => {
  searchInput.value = ''
  searchQuery.value = ''
  await fetchPosts(1, '')
}

// 記事の投稿
const submitPost = async () => {
  if (!title.value.trim() || !content.value.trim()) return
  loading.value = true
  error.value = ''

  try {
    if (use_cgi == 1){
      const res = await fetch(buildApiUrl(), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title: title.value, content: content.value })
      })
      const data = await res.json().catch(() => ({}))
      if (!res.ok) throw new Error(data.error || '投稿後にエラーが発生しました')
    }
    else{
      const res = await fetch(API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title: title.value, content: content.value })
      })
      if (!res.ok) throw new Error('投稿に失敗しました')
    }
    title.value = ''
    content.value = ''
    await fetchPosts(1, searchQuery.value)
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}

// 編集モード開始
const startEdit = (post) => {
  editingId.value = post.id
  editTitle.value = post.title
  editContent.value = post.content
  error.value = ''
}

// 編集キャンセル
const cancelEdit = () => {
  editingId.value = null
  editTitle.value = ''
  editContent.value = ''
}

// 記事の更新保存
const saveEdit = async (id) => {
  if (!editTitle.value.trim() || !editContent.value.trim()) return
  error.value = ''

  try {
    if (use_cgi == 1){
      const res = await fetch(buildApiUrl({ id }), {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title: editTitle.value, content: editContent.value })
      })

      const data = await res.json().catch(() => ({}))
      if (!res.ok) throw new Error(data.error || '更新に失敗しました')
      editingId.value = null
      await fetchPosts(currentPage.value, searchQuery.value)
    }
    else{
      const res = await fetch(`${API_URL}/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title: editTitle.value, content: editContent.value })
      })
      if (!res.ok) throw new Error('更新に失敗しました')

      editingId.value = null
      await fetchPosts(currentPage.value)
    }
  } catch (e) {
    error.value = e.message
  }
}

// 記事の削除
const deletePost = async (id) => {
  if (!confirm('この投稿を削除しますか？')) return
  error.value = ''

  try {
    if (use_cgi == 1){
      const res = await fetch(buildApiUrl({ id }), {
        method: 'DELETE'
      })

      const data = await res.json().catch(() => ({}))
      if (!res.ok) throw new Error(data.error || '削除に失敗しました')

      const targetPage = posts.value.length === 1 && currentPage.value > 1
        ? currentPage.value - 1
        : currentPage.value
      await fetchPosts(targetPage, searchQuery.value)
    }
    else{
      const res = await fetch(`${API_URL}/${id}`, {
        method: 'DELETE'
      })
      if (!res.ok) throw new Error('削除に失敗しました')

      // 現在のページに1件しかなかった場合、前のページへ戻る
      const targetPage = posts.value.length === 1 && currentPage.value > 1
        ? currentPage.value - 1
        : currentPage.value
      await fetchPosts(targetPage)
    }
  } catch (e) {
    error.value = e.message
  }
}

//onMounted(fetchPosts)
onMounted(() => fetchPosts(1, ''))
</script>

<template>
  <div style="max-width: 600px; margin: 40px auto; font-family: sans-serif; padding: 0 20px;">
    <h1>Perl + Vue BBS</h1>

    <!-- 投稿フォーム -->
    <form @submit.prevent="submitPost" style="background: #f9f9f9; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
      <h3>新規投稿</h3>
      <div style="margin-bottom: 10px;">
        <input v-model="title" placeholder="タイトル" style="width: 100%; padding: 8px; box-sizing: border-box;" />
      </div>
      <div style="margin-bottom: 10px;">
        <textarea v-model="content" placeholder="本文" rows="3" style="width: 100%; padding: 8px; box-sizing: border-box;"></textarea>
      </div>
      <button type="submit" :disabled="loading" style="padding: 8px 16px; background: #42b883; color: white; border: none; border-radius: 4px; cursor: pointer;">
        {{ loading ? '送信中...' : '投稿する' }}
      </button>
      <p v-if="error" style="color: red;">{{ error }}</p>
    </form>

    <!-- キーワード検索フォーム -->
    <form @submit.prevent="handleSearch" style="display: flex; gap: 8px; margin-bottom: 20px;">
      <input
        v-model="searchInput"
        placeholder="キーワードで検索（タイトル・本文）"
        style="flex: 1; padding: 8px; box-sizing: border-box;"
      />
      <button type="submit" style="padding: 8px 14px; background: #2563eb; color: white; border: none; border-radius: 4px; cursor: pointer;">
        検索
      </button>
      <button
        v-if="searchQuery"
        type="button"
        @click="clearSearch"
        style="padding: 8px 12px; background: #9ca3af; color: white; border: none; border-radius: 4px; cursor: pointer;">
        クリア
      </button>
    </form>

    <p v-if="searchQuery" style="font-size: 14px; color: #374151;">
      検索ワード: <strong>{{ searchQuery }}</strong>
    </p>

    <!-- 記事一覧 -->
    <h2>投稿一覧</h2>
    <div v-if="posts.length === 0" style="color: #666;">まだ投稿はありません。</div>
    <div v-for="post in posts" :key="post.id" style="border: 1px solid #ddd; padding: 15px; border-radius: 6px; margin-bottom: 10px;">

            <!-- 編集中フォーム -->
      <div v-if="editingId === post.id">
        <div style="margin-bottom: 8px;">
          <input v-model="editTitle" style="width: 100%; padding: 6px; box-sizing: border-box;" />
        </div>
        <div style="margin-bottom: 8px;">
          <textarea v-model="editContent" rows="3" style="width: 100%; padding: 6px; box-sizing: border-box;"></textarea>
        </div>
        <div style="display: flex; gap: 8px;">
          <button
            @click="saveEdit(post.id)"
            style="padding: 4px 12px; background: #3b82f6; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 12px;">
            保存
          </button>
          <button
            @click="cancelEdit"
            style="padding: 4px 12px; background: #9ca3af; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 12px;">
            キャンセル
          </button>
        </div>
      </div>

      <!-- 通常表示 -->
      <div v-else>
        <div style="display: flex; justify-content: space-between; align-items: start; gap: 10px;">
          <h4 style="margin: 0 0 5px 0;">{{ post.title }}</h4>
          <div style="display: flex; gap: 6px;">
            <button
              @click="startEdit(post)"
              style="padding: 4px 10px; background: #3b82f6; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 12px;">
              編集
            </button>
            <button
              @click="deletePost(post.id)"
              style="padding: 4px 10px; background: #e55353; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 12px;">
              削除
            </button>
          </div>
        </div>
        <p style="margin: 0 0 10px 0; white-space: pre-wrap;">{{ post.content }}</p>
        <small style="color: #888;">{{ post.created_at }}</small>
      </div>
    </div>

    <!-- ページネーションコントロール -->
    <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 20px;">
      <button 
        @click="fetchPosts(currentPage - 1)" 
        :disabled="currentPage <= 1"
        style="padding: 6px 12px; cursor: pointer;">
        &lt; 前へ
      </button>
      
      <span>ページ {{ currentPage }} / {{ totalPages }}</span>

      <button 
        @click="fetchPosts(currentPage + 1)" 
        :disabled="currentPage >= totalPages"
        style="padding: 6px 12px; cursor: pointer;">
        次へ &gt;
      </button>
    </div>

  </div>
</template>
