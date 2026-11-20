/**
 * Reference implementation for assigning a Supabase role claim.
 *
 * Deploy with Firebase Functions after initializing a Firebase Functions project.
 * Requires: `firebase-functions` + `firebase-admin`.
 */

const functions = require('firebase-functions')
const { initializeApp } = require('firebase-admin/app')
const { getAuth } = require('firebase-admin/auth')

initializeApp()

exports.processSignUp = functions.auth.user().onCreate(async (user) => {
  try {
    await getAuth().setCustomUserClaims(user.uid, {
      role: 'authenticated',
    })
  } catch (error) {
    console.log(error)
  }
})

