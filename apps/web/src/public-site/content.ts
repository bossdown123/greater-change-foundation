import allGalleries from './galleries.json'
export const contactEmail = 'greaterchangefoundation@outlook.com'
export const siteOrigin = 'https://greaterchangefoundation.org'
export const mission = 'To positively impact lives and encourage a deeper appreciation for life itself.'
export type Photograph = { file: string; alt: string; caption: string }
export type Story = { slug: string; title: string; year: string; category: 'Community' | 'Children' | 'Health' | 'Together'; intro: string; paragraphs: string[]; photos: Photograph[] }
const photo = (file: string, alt: string, caption: string): Photograph => ({ file, alt, caption })
export const stories: Story[] = [
  { slug: 'childs-month-2025', title: 'A day for the children.', year: '2025', category: 'Children',
    intro: 'Coming together for GCF’s Child’s Month treat.',
    paragraphs: ['Time together is a gift of its own. GCF’s Child’s Month treat brought people together for a day of conversation, presentations and giving.', 'These photographs capture the people behind the day: gathering as a team, sharing a few words and preparing gifts. A look at a community making time for its children.'],
    photos: [photo('community', 'GCF participants gathered outdoors beneath colourful banners', 'Together for Child’s Month, 2025.'), photo('child-month-gathering', 'A group stands together at the front of a bright yellow room', 'A shared moment at the gathering.'), photo('child-month-gifts', 'Participants look through bags of gifts together', 'The little details that make a day.'), photo('child-month-team', 'Members of the group speaking at the Child’s Month gathering', 'Making time to come together.'), photo('child-month-speaking', 'A speaker addresses the group with a microphone', 'A few words, shared with everyone.'), photo('child-month-friends', 'Three people smiling together at the celebration', 'Faces from the day.')] },
  { slug: 'blood-drive-2024', title: 'Showing up for one another.', year: '2024', category: 'Health',
    intro: 'People and shared purpose at the GCF blood drive.',
    paragraphs: ['GCF’s 2024 blood drive brought people together around a simple act of care. The photographs record the team and participants who gathered for the occasion.', 'Behind every community activity are people willing to show up. This collection celebrates that shared effort.'],
    photos: [photo('blood-drive-team', 'Participants gathered in front of banners at the GCF blood drive', 'Together at the GCF blood drive, 2024.'), photo('blood-drive-thanks', 'A participant holding a blue bag in front of the blood drive banners', 'A moment from the day.'), photo('blood-drive-shirt', 'Three participants holding up a Greater Change Foundation shirt', 'A shared purpose.')] },
  { slug: 'christmas-2023', title: 'More than a shared meal.', year: '2023', category: 'Community',
    intro: 'Food, care and company at GCF’s Christmas initiative.',
    paragraphs: ['The Christmas table starts long before anyone sits down. It starts with gathering supplies, preparing food and making room for one another.', 'GCF’s Christmas initiative brought those small acts together. From the kitchen to the shared meal, these photographs follow some of the people and preparation behind the day.'],
    photos: [photo('christmas-serving', 'GCF participants serving plates of food from a kitchen counter', 'Preparing to share a meal, Christmas 2023.'), photo('christmas-team', 'The Christmas initiative team gathered together in the kitchen', 'The people behind the preparation.'), photo('christmas-gifts', 'Two people standing beside boxes of food supplies', 'Supplies gathered for the initiative.'), photo('christmas-meals', 'Volunteers arranging prepared meals in the kitchen', 'Care in the preparation.'), photo('christmas-preparation', 'Plates of food being prepared by a group of volunteers', 'Many hands, one shared table.')] },
  { slug: 'anniversary-celebration', title: 'A moment to come together.', year: '2023', category: 'Together',
    intro: 'Faces and moments from GCF’s anniversary celebration.',
    paragraphs: ['An anniversary is a chance to pause, share memories and recognise the people who are part of the journey.', 'GCF’s anniversary collection captures that time together: conversation, a celebration cake and words shared with the room.'],
    photos: [photo('anniversary-together', 'People gathered around an anniversary cake', 'Together at GCF’s anniversary celebration.'), photo('anniversary-cake', 'A decorated cake at the anniversary gathering', 'A reason to celebrate.'), photo('anniversary-speaking', 'A woman speaking at the anniversary gathering', 'Sharing a few words.'), photo('anniversary-friends', 'Two people seated together at the celebration', 'Time for conversation.')] },
  { slug: 'christmas-2022', title: 'Care, packed and shared.', year: '2022', category: 'Community',
    intro: 'A look back at GCF’s Christmas outreach.',
    paragraphs: ['Boxes of supplies, people preparing to help, and a day spent together. The photographs from GCF’s Christmas 2022 collection show care taking a practical form.', 'The work happens one contribution at a time. Here are a few moments from the preparation and delivery.'],
    photos: [photo('christmas-packing', 'People preparing boxes of supplies beside a vehicle', 'Getting ready for Christmas outreach, 2022.'), photo('christmas-supplies', 'Open boxes filled with food and supplies', 'Supplies ready to be shared.'), photo('christmas-delivery', 'A GCF participant carrying a box of supplies outdoors', 'Taking care beyond the preparation table.')] }
]
export const storyPath = (story: Story) => `/our-work/${story.slug}`
export const imagePath = (photo: Photograph, small = false) => `/assets/stories/${photo.file}${small ? '-800' : ''}.webp`
export const publicPaths = ['/', '/our-work', '/updates', '/about', '/support', '/privacy', ...stories.map(storyPath), ...stories.map(story => `/galleries/${story.slug}`)]
export function pageMeta(path: string) {
 const story = stories.find(s => storyPath(s) === path || `/galleries/${s.slug}` === path)
 const titles: Record<string,string> = { '/': 'Small acts. Greater change.', '/our-work': 'Our work', '/updates': 'Updates', '/about': 'About us', '/support': 'Be part of the change', '/privacy': 'Your privacy' }
 return { title: `${path.startsWith("/galleries/") ? "Gallery: " : ""}${story?.title || titles[path] || 'Page not found'} | Greater Change Foundation`, description: story?.intro || 'People, purpose and community. Discover the work of the Greater Change Foundation and find out how to get involved.', image: imagePath(story?.photos[0] || stories[0].photos[0]) }
}

// Inline editorial choices stay separate from the full related collection.
export function galleryPhotos(story: Story): Photograph[] {
 const chosen = new Set(story.photos.map(photo => photo.file))
 return [...story.photos, ...((allGalleries as Record<string,Photograph[]>)[story.slug] || []).filter(photo => !chosen.has(photo.file))]
}
export const galleryThumbnail = (photo: Photograph) => `/assets/stories/${photo.file}-thumb.webp`
